import ComposableCoreLocation
import XCTest

class ComposableCoreLocationTests: XCTestCase {
  func testMockHasDefaultsForAllEndpoints() {
    _ = LocationManagerClient.mock()
  }
}
