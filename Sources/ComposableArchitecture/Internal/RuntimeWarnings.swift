import Foundation

extension Notification.Name {
  #if swift(>=5.8)
    @_documentation(visibility:private)
    @available(*, deprecated, renamed: "_runtimeWarning")
    public static let runtimeWarning = Self("ComposableArchitecture.runtimeWarning")
  #else
    @available(*, deprecated, renamed: "_runtimeWarning")
    public static let runtimeWarning = Self("ComposableArchitecture.runtimeWarning")
  #endif
  /// A notification that is posted when a runtime warning is emitted.
  public static let _runtimeWarning = Self("ComposableArchitecture.runtimeWarning")
}

@_transparent
@usableFromInline
@inline(__always)
func runtimeWarn(
  _ message: @autoclosure () -> String,
  category: String? = "ComposableArchitecture"
) {
  #if DEBUG
    let message = message()
    NotificationCenter.default.post(
      name: ._runtimeWarning,
      object: nil,
      userInfo: ["message": message]
    )
    let category = category ?? "Runtime Warning"
    if _XCTIsTesting {
      XCTFail(message)
    } else {
      #if canImport(os)
        os_log(
          .fault,
          dso: dso,
          log: OSLog(subsystem: "com.apple.runtime-issues", category: category),
          "%@",
          message
        )
      #else
        fputs("\(formatter.string(from: Date())) [\(category)] \(message)\n", stderr)
      #endif
    }
  #else
    if _XCTIsTesting {
      XCTFail(message())
    }
  #endif
}

#if DEBUG
  import XCTestDynamicOverlay

  #if canImport(os)
    import os

    // NB: Xcode runtime warnings offer a much better experience than traditional assertions and
    //     breakpoints, but Apple provides no means of creating custom runtime warnings ourselves.
    //     To work around this, we hook into SwiftUI's runtime issue delivery mechanism, instead.
    //
    // Feedback filed: https://gist.github.com/stephencelis/a8d06383ed6ccde3e5ef5d1b3ad52bbc
    @usableFromInline
    let dso = { () -> UnsafeMutableRawPointer in
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
    }()
  #else
    import Foundation

    @usableFromInline
    let formatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:MM:SS.sssZ"
      return formatter
    }()
  #endif
#endif
