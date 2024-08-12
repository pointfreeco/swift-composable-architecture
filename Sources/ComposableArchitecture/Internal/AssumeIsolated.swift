import Foundation

extension MainActor {
  // NB: This functionality was not back-deployed in Swift 5.9
  static func _assumeIsolated<T: Sendable>(
    _ operation: @MainActor () throws -> T,
    file: StaticString = #fileID,
    line: UInt = #line
  ) rethrows -> T {
    #if swift(<5.10)
      typealias YesActor = @MainActor () throws -> T
      typealias NoActor = () throws -> T

      guard Thread.isMainThread else {
        fatalError(
          "Incorrect actor executor assumption; Expected same executor as \(self).",
          file: file,
          line: line
        )
      }

      return try withoutActuallyEscaping(operation) { (_ fn: @escaping YesActor) throws -> T in
        let rawFn = unsafeBitCast(fn, to: NoActor.self)
        return try rawFn()
      }
    #else
      return try assumeIsolated(operation, file: file, line: line)
    #endif
  }
}
