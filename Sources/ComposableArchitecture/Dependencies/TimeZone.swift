import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
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
