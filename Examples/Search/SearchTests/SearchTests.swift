import Combine
import ComposableArchitecture
import XCTest

@testable import Search

class SearchTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testSearchAndClearQuery() {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .environment {
        $0.weatherClient.searchLocation = { _ in Effect(value: mockLocations) }
      },
      .send(.searchQueryChanged("S")) {
        $0.searchQuery = "S"
      },
      .do { self.scheduler.advance(by: 0.3) },
      .receive(.locationsResponse(.success(mockLocations))) {
        $0.locations = mockLocations
      },
      .send(.searchQueryChanged("")) {
        $0.locations = []
        $0.searchQuery = ""
      }
    )
  }

  func testSearchFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .environment {
        $0.weatherClient.searchLocation = { _ in Effect(error: .init()) }
      },
      .send(.searchQueryChanged("S")) {
        $0.searchQuery = "S"
      },
      .do { self.scheduler.advance(by: 0.3) },
      .receive(.locationsResponse(.failure(.init())))
    )
  }

  func testClearQueryCancelsInFlightSearchRequest() {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(searchLocation: { _ in Effect(value: mockLocations) }),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.searchQueryChanged("S")) {
        $0.searchQuery = "S"
      },
      .do { self.scheduler.advance(by: 0.2) },
      .send(.searchQueryChanged("")) {
        $0.searchQuery = ""
      },
      .do { self.scheduler.run() }
    )
  }

  func testTapOnLocation() {
    let specialLocation = Location(id: 42, title: "Special Place")
    let specialLocationWeather = LocationWeather(
      consolidatedWeather: mockWeather,
      id: 42
    )

    let store = TestStore(
      initialState: .init(locations: mockLocations + [specialLocation]),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(weather: { _ in Effect(value: specialLocationWeather) }),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.locationTapped(specialLocation)) {
        $0.locationWeatherRequestInFlight = specialLocation
      },
      .do { self.scheduler.advance() },
      .receive(.locationWeatherResponse(.success(specialLocationWeather))) {
        $0.locationWeatherRequestInFlight = nil
        $0.locationWeather = specialLocationWeather
      }
    )
  }

  func testTapOnLocationCancelsInFlightRequest() {
    let specialLocation = Location(id: 42, title: "Special Place")
    let specialLocationWeather = LocationWeather(
      consolidatedWeather: mockWeather,
      id: 42
    )

    let store = TestStore(
      initialState: .init(locations: mockLocations + [specialLocation]),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(weather: { _ in Effect(value: specialLocationWeather) }),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.locationTapped(mockLocations.first!)) {
        $0.locationWeatherRequestInFlight = mockLocations.first!
      },
      .send(.locationTapped(specialLocation)) {
        $0.locationWeatherRequestInFlight = specialLocation
      },
      .do { self.scheduler.advance() },
      .receive(.locationWeatherResponse(.success(specialLocationWeather))) {
        $0.locationWeatherRequestInFlight = nil
        $0.locationWeather = specialLocationWeather
      }
    )
  }

  func testTapOnLocationFailure() {
    let store = TestStore(
      initialState: .init(locations: mockLocations),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .mock(weather: { _ in Fail(error: .init()).eraseToEffect() }),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.locationTapped(mockLocations.first!)) {
        $0.locationWeatherRequestInFlight = mockLocations.first!
      },
      .do { self.scheduler.advance() },
      .receive(.locationWeatherResponse(.failure(.init()))) {
        $0.locationWeatherRequestInFlight = nil
      }
    )
  }
}

private let mockWeather: [LocationWeather.ConsolidatedWeather] = [
  .init(
    applicableDate: Date(timeIntervalSince1970: 0),
    maxTemp: 90,
    minTemp: 70,
    theTemp: 80,
    weatherStateName: "Clear"
  ),
  .init(
    applicableDate: Date(timeIntervalSince1970: 86_400),
    maxTemp: 70,
    minTemp: 50,
    theTemp: 60,
    weatherStateName: "Rain"
  ),
  .init(
    applicableDate: Date(timeIntervalSince1970: 172_800),
    maxTemp: 100,
    minTemp: 80,
    theTemp: 90,
    weatherStateName: "Cloudy"
  ),
]

private let mockLocations = [
  Location(id: 1, title: "Brooklyn"),
  Location(id: 2, title: "Los Angeles"),
  Location(id: 3, title: "San Francisco"),
]
