//
// Code to support update of TCA Reducer functions at runtime.
//

import Foundation

#if DEBUG
    /// Creates injectable reducer
    public func ARCInjectable<T>(_ reducer: @autoclosure () -> T) -> T {
        return MakeInjectable(reducer: reducer())
    }
#else
    @inlinable @inline(__always)
    public func ARCInjectable<T>(_ reducer: T) -> T {
        return reducer
    }
#endif

/// Wrap reducers you want to be able to inject  in a call to this function.
/// Overrides are grouped by the symbol name of the one-time initialiser
/// of the top level variable being initialised in the order they are encountered.
fileprivate func MakeInjectable<T>(reducer: @autoclosure () -> T) -> T {
    #if DEBUG
    var info = Dl_info()
    let save = currentCallerSymbol
    defer { currentCallerSymbol = save }
    var callStack = Thread.callStackReturnAddresses
    while !callStack.isEmpty,
          let callerAddress = callStack.removeFirst().pointerValue,
        dladdr(callerAddress, &info) != 0,
        let nearestSymbol = info.dli_sname {
        let callerSymbol = String(cString: nearestSymbol)
        guard callerSymbol.hasSuffix("_WZ") else {
            continue // This is not initialisation of top level var
        }
        // If this callerSymbol is not initialised or injecting...
        if reducerOverrideStore.index(forKey: callerSymbol) == nil ||
            strstr(info.dli_fname, "/eval") != nil {
            INLog("Initialising", callerSymbol, "from",
                  URL(fileURLWithPath: String(cString:
                    info.dli_fname)).lastPathComponent)
            currentCallerSymbol = callerSymbol
            reducerOverrideStore[callerSymbol] = []

            let start = Date.timeIntervalSinceReferenceDate
            func notifyInjectionIII() {
                // Notifiy InjectionIII to call one-time initialiser.
                let regsel = Selector(("registerInjectableTCAReducer:"))
                if NSObject.responds(to: regsel),
                    let impl = class_getMethodImplementation(NSObject.self, regsel) {
                    typealias RegisterImpl = @convention(c)
                        (NSObject, Selector, NSString) -> Void
                    let callable = unsafeBitCast(impl, to: RegisterImpl.self)
                    callable(NSObject(), regsel, callerSymbol as NSString)
                } else {
                    // Allow time for xxOSInjection.bundle to load
                    if Date.timeIntervalSinceReferenceDate - start < 30.0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            notifyInjectionIII()
                        }
                    } else if objc_getClass("InjectionClient") != nil {
                        print("""
                            Please update your InjectionIII.app from
                            https://github.com/johnno1962/InjectionIII/releases
                            and load the injection bundle or add Swift Package:
                            https://github.com/johnno1962/HotReloading
                            """)
                    }
                }
            }

            notifyInjectionIII()
        }
        break
    }
    #endif
    return reducer()
}

#if DEBUG // Extensions for making TCA Reducers "Injectable"
/// Generic logger for debugging.
private func INLog(_ items: Any...) {
    if getenv("INJECTION_DETAIL") != nil {
        print(items.map { "\($0)" }.joined(separator: " "))
    }
}

/// Symbol for reducer currently being initialised.
private var currentCallerSymbol: String?
/// Where new versions of Reducer functions are retained by injectable symbol.
private var reducerOverrideStore = [String: [(Any.Type) -> Any]]()

/// Low level C function type of symbol for Swift function receiving generic.
private typealias FunctionTakingGenericValue = @convention(c) (
    _ valuePtr : UnsafeRawPointer?, _ outPtr: UnsafeMutableRawPointer,
    _ metaType: UnsafeRawPointer, _ witnessTable: UnsafeRawPointer?) -> ()

/**
 This can be used to call a Swift function with a generic value
 argument when you have a pointer to the value and its type.
 See: https://www.youtube.com/watch?v=ctS8FzqcRug
 */
private func thunkToGeneric(funcPtr: FunctionTakingGenericValue,
    valuePtr: UnsafeRawPointer?, outPtr: UnsafeMutableRawPointer,
    type: Any.Type, witnessTable: UnsafeRawPointer? = nil) {
    funcPtr(valuePtr, outPtr, unsafeBitCast(type, to:
                UnsafeRawPointer.self), witnessTable)
}

/// This function copies a reducer function into an Any? correctly
/// but without being too fussy about the precise type as types in
/// generics arguments of Reducer may also have been injected.
func forceType<T>(value: T, out: inout Any?) {
    out = value
}

/// Get C level function pointer to forceType Swift function.
private let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
private let forceTypeSymbol =
    "$s22ComposableArchitecture9forceType5value3outyx_ypSgztlF"
private let forceTypeCPointer = unsafeBitCast(
    dlsym(RTLD_DEFAULT, forceTypeSymbol)!,
    to: FunctionTakingGenericValue.self)

extension Reducer {
    /// The keeper of reducers  so they can be injected.
    /// Stored by the one-time initialiser symbol associated
    /// with the xxxReducer variable being initialised and
    /// and index in order each Reducer is initialised.
    struct ReducerFunctionKey {
        typealias ReducerFunc = (inout State, Action, Environment)
            -> Effect<Action, Never>

        /// Symbol of one-time initialiser of top level variable inside which this is created
        let callerSymbol: String
        /// Sequence number inside scope of the above callerSymbol
        let index: Int

        /// Store/update for later at current callerSymbol/index as an address
        static func store(reducer: @escaping ReducerFunc) -> Self? {
            guard let callerSymbol = currentCallerSymbol else { return nil }

            let index = reducerOverrideStore[callerSymbol]!.count
            INLog("Overriding", "\(callerSymbol)[\(index)]", type(of: reducer))
            let reducerGetter = {
                (desiredType: Any.Type) -> Any in
                var reducer = reducer
                var anyReducer: Any?
                // Need to force the type as Reducer
                // types may be in the injected file.
                thunkToGeneric(funcPtr: forceTypeCPointer,
                               valuePtr: &reducer,
                               outPtr: &anyReducer,
                               type: desiredType)
                return anyReducer!
            }

            reducerOverrideStore[callerSymbol]!.append(reducerGetter)
            return Self.init(callerSymbol: callerSymbol, index: index)
        }

        /// Use callerSymbol/index to retieve closure retaining the reducer function
        func lastStored() -> ReducerFunc {
            if let storedReducers = reducerOverrideStore[callerSymbol],
               let reducerGetter = index < storedReducers.count ?
                storedReducers[index] : nil, let anyReducer =
                    reducerGetter(ReducerFunc.self) as? ReducerFunc {
                return anyReducer
            } else {
                fatalError("""
                    ⚠️ Unable to rerieve injected reducer override for \
                    \(callerSymbol). Are you sure all top level reducer \
                    variables composed into this reducer have been wrapped \
                    in ARCInjectable?
                    """)
            }
        }
    }
}
#endif // Extensions for making Reducers "Injectable"

