import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// The current time zone that reducers should use when handling dates.
  public var timeZone: TimeZone {
    get { self[TimeZoneKey.self] }
    set { self[TimeZoneKey.self] = newValue }
  }

  private enum TimeZoneKey: LiveDependencyKey {
    static let liveValue = TimeZone.autoupdatingCurrent
    static var testValue: TimeZone {
      XCTFail(#"Unimplemented: @Dependency(\.timeZone)"#)
      return .autoupdatingCurrent
    }
  }
}
