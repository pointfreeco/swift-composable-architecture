import Foundation
import XCTestDynamicOverlay

#if swift(>=5.6)
  extension DependencyValues {
    /// A dependency that returns the current date.
  ///
  /// By default, a ``DateGenerator/live`` generator is supplied. When used from a `TestStore`, an
  /// ``DateGenerator/unimplemented`` generator is supplied, unless explicitly overridden, for
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

/// A dependency that generates a date.
///
/// See ``DependencyValues/date`` for more information.
  public struct DateGenerator: Sendable {
    private let generate: @Sendable () -> Date

  /// A generator that returns a constant date.
  ///
  /// - Parameter now: A date to return.
  /// - Returns: A generator that always returns the given date.
    public static func constant(_ now: Date) -> Self {
      Self { now }
    }

  /// A generator that calls `Date()` under the hood.
    public static let live = Self { Date() }

  /// A generator that calls `XCTFail` when it is invoked.
    public static let unimplemented = Self {
      XCTFail(#"Unimplemented: @Dependency(\.date)"#)
      return Date()
    }

    public func callAsFunction() -> Date {
      self.generate()
    }
  }
#endif
