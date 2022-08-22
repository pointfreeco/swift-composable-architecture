import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that returns the current date.
  ///
  /// By default, a ``DateGenerator/live`` generator is supplied. When used from a ``TestStore``,
  /// an ``DateGenerator/unimplemented`` generator is supplied, unless explicitly overridden, for
  /// example using a ``DateGenerator/constant(_:)`` generator:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: My.Feature()
  /// )
  ///
  /// store.dependencies.date = .constant(Date(timeIntervalSince1970: 0))
  /// ```
  public var date: DateGenerator {
    get { self[DateGeneratorKey.self] }
    set { self[DateGeneratorKey.self] = newValue }
  }

  private enum DateGeneratorKey: LiveDependencyKey {
    static let liveValue: DateGenerator = .live
    static let testValue: DateGenerator = .unimplemented
  }
}

public struct DateGenerator: Sendable {
  private let generate: @Sendable () -> Date

  public static func constant(_ now: Date) -> Self {
    Self { now }
  }

  public static let live = Self { Date() }

  public static let unimplemented = Self {
    XCTFail(#"Unimplemented: @Dependency(\.date)"#)
    return Date()
  }

  public func callAsFunction() -> Date {
    self.generate()
  }
}
