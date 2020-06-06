import ComposableCoreLocation
import XCTest

class ComposableCoreLocationTests: XCTestCase {
  func testMockHasDefaultsForAllEndpoints() {
    _ = LocationManager.mock()
  }

  func testLocationEncodeDecode() {
    let value = Location(
      altitude: 50,
      coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 20),
      course: 9,
      courseAccuracy: 1,
      horizontalAccuracy: 3,
      speed: 5,
      speedAccuracy: 2,
      timestamp: Date.init(timeIntervalSince1970: 0),
      verticalAccuracy: 6
    )

    let data = try? JSONEncoder().encode(value)
    let decoded = try? JSONDecoder().decode(Location.self, from: data ?? Data())

    XCTAssertEqual(value, decoded)
  }
}
