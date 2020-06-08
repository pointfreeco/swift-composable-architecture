import ComposableCoreLocation
import XCTest

class ComposableCoreLocationTests: XCTestCase {
  func testMockHasDefaultsForAllEndpoints() {
    _ = LocationManager.mock()
  }

  func testLocationEncodeDecode() {
    let value: Location

    #if compiler(>=5.2)
      if #available(iOS 13.4, macCatalyst 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
        value = Location(
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
      } else {
        value = Location(
          altitude: 50,
          coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 20),
          course: 9,
          horizontalAccuracy: 3,
          speed: 5,
          timestamp: Date.init(timeIntervalSince1970: 0),
          verticalAccuracy: 6
        )
      }
    #else
      value = Location(
        altitude: 50,
        coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 20),
        course: 9,
        horizontalAccuracy: 3,
        speed: 5,
        timestamp: Date.init(timeIntervalSince1970: 0),
        verticalAccuracy: 6
      )
    #endif

    let data = try? JSONEncoder().encode(value)
    let decoded = try? JSONDecoder().decode(Location.self, from: data ?? Data())

    XCTAssertEqual(value, decoded)
  }

  func testLocationEquatable() {
    let a = Location(
      altitude: 1,
      coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
      course: 1,
      horizontalAccuracy: 1,
      speed: 1,
      timestamp: Date.init(timeIntervalSince1970: 0),
      verticalAccuracy: 1
    )

    let b = Location(
      altitude: 2,
      coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 2),
      course: 2,
      horizontalAccuracy: 2,
      speed: 2,
      timestamp: Date.init(timeIntervalSince1970: 1),
      verticalAccuracy: 2
    )

    XCTAssertTrue(a == a)
    XCTAssertFalse(a == b)
  }

  #if compiler(>=5.2)
    func testLocationEquatable_5_2() {
      if #available(iOS 13.4, macCatalyst 13.4, macOS 10.15.4, tvOS 13.4, watchOS 6.2, *) {
        let a = Location(
          altitude: 1,
          coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
          course: 1,
          courseAccuracy: 1,
          horizontalAccuracy: 1,
          speed: 1,
          speedAccuracy: 1,
          timestamp: Date.init(timeIntervalSince1970: 0),
          verticalAccuracy: 1
        )

        let b = Location(
          altitude: 1,
          coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
          course: 1,
          courseAccuracy: 1,
          horizontalAccuracy: 1,
          speed: 1,
          speedAccuracy: 2,
          timestamp: Date.init(timeIntervalSince1970: 0),
          verticalAccuracy: 1
        )

        let c = Location(
          altitude: 1,
          coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1),
          course: 1,
          courseAccuracy: 2,
          horizontalAccuracy: 1,
          speed: 1,
          speedAccuracy: 1,
          timestamp: Date.init(timeIntervalSince1970: 0),
          verticalAccuracy: 1
        )

        XCTAssertTrue(a == a)
        XCTAssertFalse(a == b)
        XCTAssertFalse(a == c)
      }
    }
  #endif
}
