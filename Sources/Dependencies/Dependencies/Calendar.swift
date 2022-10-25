import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// The current calendar that features should use when handling dates.
  ///
  /// By default, the calendar returned from `Calendar.autoupdatingCurrent` is supplied. When used
  /// in a testing context, access will call to `XCTFail` when invoked, unless explicitly
  /// overridden using ``withValue(_:_:operation:)-705n``:
  ///
  /// ```swift
  /// DependencyValues.withValue(\.calendar, Calendar(identifier: .gregorian)) {
  ///   // Assertions...
  /// }
  /// ```
  ///
  /// Or, if you are using the Composable Architecture, you can override dependencies directly
  /// on the `TestStore`:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: MyFeature()
  /// )
  ///
  /// store.dependencies.calendar = Calendar(identifier: .gregorian)
  /// ```
  public var calendar: Calendar {
    get { self[CalendarKey.self] }
    set { self[CalendarKey.self] = newValue }
  }

  private enum CalendarKey: DependencyKey {
    static let liveValue = Calendar.autoupdatingCurrent
    static var testValue: Calendar {
      if !DependencyValues.isSetting {
        XCTFail(#"Unimplemented: @Dependency(\.calendar)"#)
      }
      return .autoupdatingCurrent
    }
  }
}
