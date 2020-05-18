import Combine
import ComposableArchitecture
import CoreLocation
import MapKit
import XCTest

@testable import LocationManager

class LocationManagerTests: XCTestCase {
  func testRequestLocation_Allow() {
    var didRequestInUseAuthorization = false
    var didRequestLocation = false
    let locationManagerSubject = PassthroughSubject<LocationManagerClient.Action, Never>()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        localSearch: .mock(),
        locationManager: .mock(
          authorizationStatus: { .notDetermined },
          create: { _ in locationManagerSubject.eraseToEffect() },
          locationServicesEnabled: { true },
          requestLocation: { _ in .fireAndForget { didRequestLocation = true } },
          requestWhenInUseAuthorization: { _ in
            .fireAndForget { didRequestInUseAuthorization = true }
          }
        )
      )
    )

    let currentLocation = Location(
      altitude: 0,
      coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 20),
      course: 0,
      courseAccuracy: 0,
      floor: nil,
      horizontalAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: Date(timeIntervalSince1970: 1_234_567_890),
      verticalAccuracy: 0
    )

    store.assert(
      .send(.onAppear),

      // Tap on the button to request current location
      .send(.currentLocationButtonTapped) {
        $0.isRequestingCurrentLocation = true
      },
      .do {
        XCTAssertTrue(didRequestInUseAuthorization)
      },

      // Simulate being given authorized to access location
      .do {
        locationManagerSubject.send(.didChangeAuthorization(.authorizedAlways))
      },
      .receive(.locationManager(.didChangeAuthorization(.authorizedAlways))),
      .do {
        XCTAssertTrue(didRequestLocation)
      },

      // Simulate finding the user's current location
      .do {
        locationManagerSubject.send(.didUpdateLocations([currentLocation]))
      },
      .receive(.locationManager(.didUpdateLocations([currentLocation]))) {
        $0.isRequestingCurrentLocation = false
        $0.region = CoordinateRegion(
          center: CLLocationCoordinate2D(latitude: 10, longitude: 20),
          span: MKCoordinateSpan.init(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
      },

      .do {
        locationManagerSubject.send(completion: .finished)
      }
    )
  }

  func testRequestLocation_Deny() {
    var didRequestInUseAuthorization = false
    let locationManagerSubject = PassthroughSubject<LocationManagerClient.Action, Never>()

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        localSearch: .mock(),
        locationManager: .mock(
          authorizationStatus: { .notDetermined },
          create: { _ in locationManagerSubject.eraseToEffect() },
          locationServicesEnabled: { true },
          requestWhenInUseAuthorization: { _ in
            .fireAndForget { didRequestInUseAuthorization = true }
          }
        )
      )
    )

    store.assert(
      .send(.onAppear),

      .send(.currentLocationButtonTapped) {
        $0.isRequestingCurrentLocation = true
      },
      .do {
        XCTAssertTrue(didRequestInUseAuthorization)
      },

      // Simulate the user denying location access
      .do {
        locationManagerSubject.send(.didChangeAuthorization(.denied))
      },
      .receive(.locationManager(.didChangeAuthorization(.denied))) {
        $0.alert = "Location makes this app better. Please consider giving us access."
        $0.isRequestingCurrentLocation = false
      },

      .do {
        locationManagerSubject.send(completion: .finished)
      }
    )
  }

  func testSearchPointsOfInterest_TapCategory() {
    let mapItem = MapItem(
      isCurrentLocation: false,
      name: "Blob's Cafe",
      phoneNumber: nil,
      placemark: Placemark(),
      pointOfInterestCategory: .cafe,
      timeZone: nil,
      url: nil
    )
    let localSearchResponse = LocalSearchResponse(
      boundingRegion: MKCoordinateRegion(),
      mapItems: [mapItem]
    )

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        localSearch: .mock(
          search: { _ in .result { .success(localSearchResponse) } }
        ),
        locationManager: .mock()
      )
    )

    store.assert(
      .send(.categoryButtonTapped(.cafe)) {
        $0.pointOfInterestCategory = .cafe
      },
      .receive(.localSearchResponse(.success(localSearchResponse))) {
        $0.pointsOfInterest = [
          PointOfInterest(
            coordinate: CLLocationCoordinate2D(),
            subtitle: nil,
            title: "Blob's Cafe"
          )
        ]
      }
    )
  }

  func testSearchPointsOfInterest_PanMap() {
    let mapItem = MapItem(
      isCurrentLocation: false,
      name: "Blob's Cafe",
      phoneNumber: nil,
      placemark: Placemark(),
      pointOfInterestCategory: .cafe,
      timeZone: nil,
      url: nil
    )
    let localSearchResponse = LocalSearchResponse(
      boundingRegion: MKCoordinateRegion(),
      mapItems: [mapItem]
    )

    let store = TestStore(
      initialState: AppState(
        pointOfInterestCategory: .cafe
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        localSearch: .mock(
          search: { request in
            return .result { .success(localSearchResponse) }
          }),
        locationManager: .mock()
      )
    )

    let coordinateRegion = CoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 10, longitude: 20),
      span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 2)
    )

    store.assert(
      .send(.updateRegion(coordinateRegion)) {
        $0.region = coordinateRegion
      },
      .receive(.localSearchResponse(.success(localSearchResponse))) {
        $0.pointsOfInterest = [
          PointOfInterest(
            coordinate: CLLocationCoordinate2D(),
            subtitle: nil,
            title: "Blob's Cafe"
          )
        ]
      }
    )
  }
}
