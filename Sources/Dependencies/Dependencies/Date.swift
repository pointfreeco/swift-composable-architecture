import Foundation
import XCTestDynamicOverlay

#if swift(>=5.6)
  extension DependencyValues {
    /// A dependency that returns the current date.
    ///
    /// By default, a ``DateGenerator/live`` generator is supplied. When used from a `TestStore`, an
    /// ``DateGenerator/unimplemented`` generator is supplied, unless explicitly overridden.
    ///
    /// You can access the current date from a reducer by introducing a `Dependency` property
    /// wrapper to the generator's ``DateGenerator/now`` property:
    ///
    /// ```swift
    /// struct MyFeature: ReducerProtocol {
    ///   @Dependency(\.date.now) var now
    ///   // ...
    /// }
    /// ```
    ///
    /// To override the current date in tests, you can assign the generator's ``DateGenerator/now``
    /// property:
    ///
    /// ```swift
    /// let store = TestStore(
    ///   initialState: MyFeature.State()
    ///   reducer: My.Feature()
    /// )
    ///
    /// store.dependencies.date.now = Date(timeIntervalSince1970: 0)
    /// ```
    public var date: DateGenerator {
      get { self[DateGeneratorKey.self] }
      set { self[DateGeneratorKey.self] = newValue }
    }

    private enum DateGeneratorKey: DependencyKey {
      static let liveValue: DateGenerator = .live
      static let testValue: DateGenerator = .unimplemented
    }
  }

  /// A dependency that generates a date.
  ///
  /// See ``DependencyValues/date`` for more information.
  public struct DateGenerator: Sendable {
    private var generate: @Sendable () -> Date

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

    /// The current date.
    public var now: Date {
      get { self.generate() }
      set { self.generate = { newValue } }
    }

    public func callAsFunction() -> Date {
      self.generate()
    }
  }
#endif
