import Combine
import ComposableArchitecture
import XCTest

@testable import Search

class SearchTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testSearchAndClearQuery() {
    let store = TestStore(
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.environment.weatherClient.search = { _ in Effect(value: .mock) }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    self.scheduler.advance(by: 0.3)
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
      initialState: .init(),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.environment.weatherClient.search = { _ in Effect(error: .init()) }
    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    self.scheduler.advance(by: 0.3)
    store.receive(.searchResponse(.failure(.init())))
  }

  func testClearQueryCancelsInFlightSearchRequest() {
    var weatherClient = WeatherClient.failing
    weatherClient.search = { _ in Effect(value: .mock) }

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
    self.scheduler.advance(by: 0.2)
    store.send(.searchQueryChanged("")) {
      $0.searchQuery = ""
    }
    self.scheduler.run()
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

    var weatherClient = WeatherClient.failing
    weatherClient.forecast = { _ in Effect(value: .mock) }

    let store = TestStore(
      initialState: .init(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    self.scheduler.advance()
    store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = .init(
        id: 42,
        days: [
          .init(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          .init(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          .init(
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

    var weatherClient = WeatherClient.failing
    weatherClient.forecast = { _ in Effect(value: .mock) }

    let store = TestStore(
      initialState: .init(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    self.scheduler.advance()
    store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = .init(
        id: 42,
        days: [
          .init(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          .init(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          .init(
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
    var weatherClient = WeatherClient.failing
    weatherClient.forecast = { _ in Effect(error: .init()) }

    let results = Search.mock.results

    let store = TestStore(
      initialState: .init(results: results),
      reducer: searchReducer,
      environment: SearchEnvironment(
        weatherClient: weatherClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    self.scheduler.advance()
    store.receive(.forecastResponse(1, .failure(.init()))) {
      $0.resultForecastRequestInFlight = nil
    }
  }
}
