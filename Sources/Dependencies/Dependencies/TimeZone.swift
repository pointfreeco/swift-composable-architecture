import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// The current time zone that features should use when handling dates.
  ///
  /// By default, the time zone returned from `TimeZone.autoupdatingCurrent` is supplied. When
  /// used from a `TestStore`, access will call to `XCTFail` when invoked, unless explicitly
  /// overridden:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: MyFeature()
  /// )
  ///
  /// store.dependencies.timeZone = TimeZone(secondsFromGMT: 0)
  /// ```
  public var timeZone: TimeZone {
    get { self[TimeZoneKey.self] }
    set { self[TimeZoneKey.self] = newValue }
  }

  private enum TimeZoneKey: DependencyKey {
    static let liveValue = TimeZone.autoupdatingCurrent
    static var testValue: TimeZone {
      if !DependencyValues.isSetting {
        XCTFail(#"Unimplemented: @Dependency(\.timeZone)"#)
      }
      return .autoupdatingCurrent
    }
  }
}
