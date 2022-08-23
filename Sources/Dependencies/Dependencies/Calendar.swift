import Foundation
import XCTestDynamicOverlay

#if swift(>=5.6)
  extension DependencyValues {
    /// The current calendar that reducers should use when handling dates.
    ///
    /// By default, the calendar returned from `Calendar.autoupdatingCurrent` is supplied. When used
    /// from a `TestStore`, access will call to `XCTFail` when invoked, unless explicitly
    /// overridden:
    ///
    /// ```swift
    /// let store = TestStore(
    ///   initialState: MyFeature.State()
    ///   reducer: My.Feature()
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
        XCTFail(#"Unimplemented: @Dependency(\.calendar)"#)
        return .autoupdatingCurrent
      }
    }
  }
#endif
