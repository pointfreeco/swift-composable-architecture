#if DEBUG
  import os
  import XCTestDynamicOverlay

  // NB: Xcode runtime warnings offer a much better experience than traditional assertions and
  //     breakpoints, but Apple provides no means of creating custom runtime warnings ourselves.
  //     To work around this, we hook into SwiftUI's runtime issue delivery mechanism, instead.
  //
  // Feedback filed: https://gist.github.com/stephencelis/a8d06383ed6ccde3e5ef5d1b3ad52bbc
  @usableFromInline
  let rw = (
    dso: { () -> UnsafeMutableRawPointer in
      let count = _dyld_image_count()
      for i in 0..<count {
        if let name = _dyld_get_image_name(i) {
          let swiftString = String(cString: name)
          if swiftString.hasSuffix("/SwiftUI") {
            if let header = _dyld_get_image_header(i) {
              return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(header))
            }
          }
        }
      }
      return UnsafeMutableRawPointer(mutating: #dsohandle)
    }(),
    log: OSLog(subsystem: "com.apple.runtime-issues", category: "ComposableArchitecture")
  )
#endif

@_transparent
@usableFromInline
@inline(__always)
func runtimeWarning(
  _ message: @autoclosure () -> StaticString,
  _ args: @autoclosure () -> [CVarArg] = [],
  file: StaticString? = nil,
  line: UInt? = nil
) {
  #if DEBUG
    let message = message()
    if _XCTIsTesting {
      if let file = file, let line = line {
        XCTFail(String(format: "\(message)", arguments: args()), file: file, line: line)
      } else {
        XCTFail(String(format: "\(message)", arguments: args()))
      }
    } else {
      unsafeBitCast(
        os_log as (OSLogType, UnsafeRawPointer, OSLog, StaticString, CVarArg...) -> Void,
        to: ((OSLogType, UnsafeRawPointer, OSLog, StaticString, [CVarArg]) -> Void).self
      )(.fault, rw.dso, rw.log, message, args())
    }
  #endif
}
