import XCTest
@testable import LocationManager
import ComposableArchitecture

class LocationManagerTests: XCTestCase {
  func testExample() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        localSearch: .mock(),
        locationManager: .mock()
      )
    )
  }
}
