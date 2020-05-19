import XCTest
import ComposableCoreLocation

class ComposableCoreLocationTests: XCTestCase {
  func testMockHasDefaultsForAllEndpoints() {
    _ = LocationManagerClient.mock()
  }
}
