
#if DEBUG // Extensions for making Reducers "Injectable"
/// Generic logger for debugging.
func INLog(_ items: Any...) {
    if getenv("INJECTION_DETAIL") != nil {
        print(items.map { "\($0)" }.joined(separator: " "))
    }
}
/// Low level function type of symbol for Swift function recieving generic.
typealias FunctionTakingGenericValue = @convention(c) (
    _ valuePtr : UnsafeRawPointer?, _ outPtr: UnsafeMutableRawPointer,
    _ metaType: UnsafeRawPointer, _ witnessTable: UnsafeRawPointer?) -> ()

/**
 This can be used to call a Swift function with a generic value
 argument when you have a pointer to the value and its type.
 See: https://www.youtube.com/watch?v=ctS8FzqcRug
 */
func thunkToGeneric(funcPtr: FunctionTakingGenericValue,
    valuePtr: UnsafeRawPointer?, outPtr: UnsafeMutableRawPointer,
    type: Any.Type, witnessTable: UnsafeRawPointer? = nil) {
    funcPtr(valuePtr, outPtr, unsafeBitCast(type, to:
                UnsafeRawPointer.self), witnessTable)
}

/// This function copies a reducer funtion into an Any?
/// but without being too fussy about the precise type
/// as types in generic may also have been injected.
func forceType<T>(value: T, out: inout Any?) {
    out = value
}

/// Get C level function pointer to forceType Swift function.
private let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
private let forceTypeSymbol = "$s22ComposableArchitecture9forceType5value3outyx_ypSgztlF"
let forceTypeCPointer = unsafeBitCast(
    dlsym(RTLD_DEFAULT, forceTypeSymbol)!,
    to: FunctionTakingGenericValue.self)

/// Symbol for reducer currently being initialised.
var currentInjectable: String?
/// Where new versions of Reducer functions are retained by injectable symbol.
var reducerOverrides = [String: [(Any.Type) -> Any]]()
#endif // Extensions for making Reducers "Injectable"

/// Wrap reducers you want to be able to inject  in a call to this function.
/// Overrides are grouped by the symbol name of the one-time initialiser
/// of the top level variable being initialised in the order they are encountered.
public func MakeInjectable<T>(reducer: @autoclosure () -> T) -> T {
    #if DEBUG
    var info = Dl_info()
    let save = currentInjectable
    defer { currentInjectable = save }
    if let from = Thread.callStackReturnAddresses[1].pointerValue,
        dladdr(from, &info) != 0, let sname = info.dli_sname {
        let callerSymbol = String(cString: sname)
        if reducerOverrides.index(forKey: callerSymbol) == nil ||
            strstr(info.dli_fname, "/eval") != nil {
            INLog("Initialising", callerSymbol, "from",
                 URL(fileURLWithPath: String(cString: info.dli_fname)).lastPathComponent)
            currentInjectable = callerSymbol
            reducerOverrides[callerSymbol] = []

            let regsel = Selector(("registerInjectableTCAReducer:"))
            if let impl = class_getMethodImplementation(NSObject.self, regsel) {
                typealias registerImpl = @convention(c)
                    (AnyClass, Selector, NSString) -> Void
                let callable = unsafeBitCast(impl, to: registerImpl.self)
                callable(NSObject.self, regsel, callerSymbol as NSString)
            } else {
                print("Please update your InjectionIII.app from https://github.com/johnno1962/InjectionIII/releases")
            }
        }
    }
    #endif
    return reducer()
}
