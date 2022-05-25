import Combine
import ComposableArchitecture
import XCTest

@testable import Search

@MainActor
class SearchTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testSearchAndClearQuery() async {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .failing,
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.environment.weatherClient.searchLocation = { _ in
      mockLocations
    }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
//    await task.yield()
    await self.scheduler.advance(by: 0.3)
//    await task.yield()
//    self.scheduler.advance()
    await store.receive(.locationsResponse(.success(mockLocations))) {
      $0.locations = mockLocations
    }
    store.send(.searchQueryChanged("")) {
      $0.locations = []
      $0.searchQuery = ""
    }
  }

  func testSearchFailure() async {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    struct SearchLocationError: Error, Equatable {}
    store.environment.weatherClient.searchLocation = { _ in throw SearchLocationError() }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await self.scheduler.advance(by: 0.3)
    
    await store.receive(.locationsResponse(.failure(SearchLocationError())), timeout: NSEC_PER_SEC*10)
  }

  func testClearQueryCancelsInFlightSearchRequest() async {
    var weatherClient = WeatherClient.failing
    weatherClient.searchLocation = { _ in mockLocations }

    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await self.scheduler.advance(by: 0.2)
    store.send(.searchQueryChanged("")) {
      $0.searchQuery = ""
    }
    await self.scheduler.run()
  }

  func testTapOnLocation() async {
    let specialLocation = Location(id: 42, title: "Special Place")
    let specialLocationWeather = LocationWeather(
      consolidatedWeather: mockWeather,
      id: 42
    )

    var weatherClient = WeatherClient.failing
    weatherClient.weather = { _ in specialLocationWeather }

    let store = TestStore(
      initialState: .init(locations: mockLocations + [specialLocation]),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.locationTapped(specialLocation)) {
      $0.locationWeatherRequestInFlight = specialLocation
    }
    await self.scheduler.advance()
    await store.receive(.locationWeatherResponse(.success(specialLocationWeather))) {
      $0.locationWeatherRequestInFlight = nil
      $0.locationWeather = specialLocationWeather
    }
  }

  func testTapOnLocationCancelsInFlightRequest() async {
    let specialLocation = Location(id: 42, title: "Special Place")
    let specialLocationWeather = LocationWeather(
      consolidatedWeather: mockWeather,
      id: 42
    )

    var weatherClient = WeatherClient.failing
    weatherClient.weather = { _ in specialLocationWeather }

    let store = TestStore(
      initialState: .init(locations: mockLocations + [specialLocation]),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.locationTapped(mockLocations.first!)) {
      $0.locationWeatherRequestInFlight = mockLocations.first!
    }
    store.send(.locationTapped(specialLocation)) {
      $0.locationWeatherRequestInFlight = specialLocation
    }
    await self.scheduler.advance()
    await store.receive(.locationWeatherResponse(.success(specialLocationWeather))) {
      $0.locationWeatherRequestInFlight = nil
      $0.locationWeather = specialLocationWeather
    }
  }

  func testTapOnLocationFailure() async {
    struct WeatherError: Error, Equatable {}

    var weatherClient = WeatherClient.failing
    weatherClient.weather = { _ in throw WeatherError() }

    let store = TestStore(
      initialState: .init(locations: mockLocations),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.locationTapped(mockLocations.first!)) {
      $0.locationWeatherRequestInFlight = mockLocations.first!
    }
    await self.scheduler.advance()
    await store.receive(.locationWeatherResponse(.failure(WeatherError()))) {
      $0.locationWeatherRequestInFlight = nil
    }
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
