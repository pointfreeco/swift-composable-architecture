//
// Code to support update of TCA Reducer functions at runtime.
//

import Foundation

#if !DEBUG
    @inlinable @inline(__always)
    public func ARCInjectable<T>(_ reducer: T) -> T {
        return reducer
    }
#else // Extensions for making TCA legacy AnyReducers "Injectable"
    /// Creates injectable reducer
    /// Wrap reducers you want to be able to inject  in a call to this function.
    public func ARCInjectable<State, Action, Environment>(_ reducer:
        @autoclosure () -> AnyReducer<State, Action, Environment>)
        -> AnyReducer<State, Action, Environment> {
        return MakeInjectable(reducer: reducer)
    }

/// One time initialiser symbol for top level reducer variable being initialised.
private var currentCallerSymbol: String?
/// Where new versions of Reducer functions are retained by caller symbol.
private var reducerOverrideStore = [String: [(Any.Type) -> Any]]()

/// Overrides are grouped by the symbol name of the one-time initialiser
/// of the top level variable being initialised in the order they are encountered.
fileprivate func MakeInjectable<State, Action, Environment>(
    reducer: () -> AnyReducer<State, Action, Environment>)
                -> AnyReducer<State, Action, Environment> {
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
                            Please update your InjectionIII.app from \
                            https://github.com/johnno1962/InjectionIII/releases \
                            and load the injection bundle or add Swift Package: \
                            https://github.com/johnno1962/HotReloading
                            """)
                    }
                }
            }

            notifyInjectionIII()
        }

        // The reducer store can store anything as a closure returning Any.
        // You specify the exact type to return when you call the closure.
        typealias StoredReducer = AnyReducer<State, Action, Environment>
        let original = reducer()
        let index = reducerOverrideStore[callerSymbol]!.count
        INLog("Overriding", "\(callerSymbol)[\(index)]", type(of: original))
        reducerOverrideStore[callerSymbol]!.append({
            (desiredType: Any.Type) -> Any in
            var reducer = original
            var anyReducer: Any?
            // Need to "force" the type as the AnyReducer generic
            // parameter types may themselves have been injected.
            thunkToGeneric(funcPtr: forceTypeCPointer,
                           valuePtr: &reducer,
                           outPtr: &anyReducer,
                           type: desiredType)
            return anyReducer!
        })

        // Create a fake reducer function that captures
        // the top level variable being initialized and
        // an index of which reducer is being captured.
        // This fishes the current reducer implementation
        // out of the store and passes any call to reduce
        // onto it. Injecting a source file updates the
        // store by the InjectionIII app calling the top
        // level variable initialiser (symbol *_WZ) again.
        // https://github.com/johnno1962/HotReloading/blob/main/Sources/HotReloading/ReducerInjection.swift#L48
        return StoredReducer {
            (state: inout State, action, env) -> EffectTask<Action> in
            if let storedReducers = reducerOverrideStore[callerSymbol],
               let reducerGetter = index < storedReducers.count ?
                storedReducers[index] : nil, let anyReducer =
                    reducerGetter(StoredReducer.self) as? StoredReducer {
                return anyReducer(&state, action, env)
            } else {
                print("""

                    ⚠️ Unable to retrieve injected reducer override for \
                    \(callerSymbol)[\(index)] as \(StoredReducer.self). \
                    Are you sure all top level reducer variables composed \
                    into this reducer have been wrapped in ARCInjectable? ⚠️

                    """)
                // can fallback to original reducer.
                return original(&state, action, env)
            }
        }
    }

    return reducer()
}

/// Generic logger for debugging.
private func INLog(_ items: Any...) {
    if getenv("INJECTION_DETAIL") != nil {
        print(items.map { "\($0)" }.joined(separator: " "))
    }
}

/// Low level C function type of symbol for Swift function receiving generic (+ conformance)
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
/// Called via thunkToGeneric() to force the type recorded in Any.
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

#endif // Extensions for making TCA legacy AnyReducers "Injectable"
