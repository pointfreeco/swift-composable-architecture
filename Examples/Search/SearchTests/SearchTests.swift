import Combine
import ComposableArchitecture
import XCTest

@testable import Search

class SearchTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testSearchAndClearQuery() {
    let store = TestStore(
      initialState: SearchState(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .unimplemented,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.environment.weatherClient.search = { _ in Effect(value: .mock) }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    self.mainQueue.advance(by: 0.3)
    store.receive(.searchResponse(.success(.mock))) {
      $0.results = Search.mock.results
    }
    store.send(.searchQueryChanged("")) {
      $0.results = []
      $0.searchQuery = ""
    }
  }

  func testSearchFailure() {
    let store = TestStore(
      initialState: SearchState(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .unimplemented,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.environment.weatherClient.search = { _ in Effect(error: WeatherClient.Failure()) }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    self.mainQueue.advance(by: 0.3)
    store.receive(.searchResponse(.failure(WeatherClient.Failure())))
  }

  func testClearQueryCancelsInFlightSearchRequest() {
    var weatherClient = WeatherClient.unimplemented
    weatherClient.search = { _ in Effect(value: .mock) }

    let store = TestStore(
      initialState: SearchState(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    self.mainQueue.advance(by: 0.2)
    store.send(.searchQueryChanged("")) {
      $0.searchQuery = ""
    }
    self.mainQueue.run()
  }

  func testTapOnLocation() {
    let specialResult = Search.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = Search.mock.results
    results.append(specialResult)

    var weatherClient = WeatherClient.unimplemented
    weatherClient.forecast = { _ in Effect(value: .mock) }

    let store = TestStore(
      initialState: SearchState(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    self.mainQueue.advance()
    store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = SearchState.Weather(
        id: 42,
        days: [
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 172_800),
            temperatureMax: 100,
            temperatureMaxUnit: "°F",
            temperatureMin: 80,
            temperatureMinUnit: "°F"
          ),
        ]
      )
    }
  }

  func testTapOnLocationCancelsInFlightRequest() {
    let specialResult = Search.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = Search.mock.results
    results.append(specialResult)

    var weatherClient = WeatherClient.unimplemented
    weatherClient.forecast = { _ in Effect(value: .mock) }

    let store = TestStore(
      initialState: SearchState(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    self.mainQueue.advance()
    store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = SearchState.Weather(
        id: 42,
        days: [
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          SearchState.Weather.Day(
            date: Date(timeIntervalSince1970: 172_800),
            temperatureMax: 100,
            temperatureMaxUnit: "°F",
            temperatureMin: 80,
            temperatureMinUnit: "°F"
          ),
        ]
      )
    }
  }

  func testTapOnLocationFailure() {
    var weatherClient = WeatherClient.unimplemented
    weatherClient.forecast = { _ in Effect(error: WeatherClient.Failure()) }

    let results = Search.mock.results

    let store = TestStore(
      initialState: SearchState(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    self.mainQueue.advance()
    store.receive(.forecastResponse(1, .failure(WeatherClient.Failure()))) {
      $0.resultForecastRequestInFlight = nil
    }
  }
}
