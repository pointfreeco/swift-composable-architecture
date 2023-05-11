import ComposableArchitecture
import XCTest

@testable import Search

@MainActor
final class SearchTests: XCTestCase {
  func testSearchAndClearQuery() async {
    let store = TestStore(initialState: Search.State()) {
      Search()
    } withDependencies: {
      $0.weatherClient.search = { _ in .mock }
    }

    await store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await store.send(.searchQueryChangeDebounced)
    await store.receive(.searchResponse(.success(.mock))) {
      $0.results = GeocodingSearch.mock.results
    }
    await store.send(.searchQueryChanged("")) {
      $0.results = []
      $0.searchQuery = ""
    }
  }

  func testSearchFailure() async {
    let store = TestStore(initialState: Search.State()) {
      Search()
    } withDependencies: {
      $0.weatherClient.search = { _ in throw SomethingWentWrong() }
    }

    await store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await store.send(.searchQueryChangeDebounced)
    await store.receive(.searchResponse(.failure(SomethingWentWrong())))
  }

  func testClearQueryCancelsInFlightSearchRequest() async {
    let store = TestStore(initialState: Search.State()) {
      Search()
    } withDependencies: {
      $0.weatherClient.search = { _ in .mock }
    }

    let searchQueryChanged = await store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await searchQueryChanged.cancel()
    await store.send(.searchQueryChanged("")) {
      $0.searchQuery = ""
    }
  }

  func testTapOnLocation() async {
    let specialResult = GeocodingSearch.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = GeocodingSearch.mock.results
    results.append(specialResult)

    let store = TestStore(initialState: Search.State(results: results)) {
      Search()
    } withDependencies: {
      $0.weatherClient.forecast = { _ in .mock }
    }

    await store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    await store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = Search.State.Weather(
        id: 42,
        days: [
          Search.State.Weather.Day(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          Search.State.Weather.Day(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          Search.State.Weather.Day(
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

  func testTapOnLocationCancelsInFlightRequest() async {
    let specialResult = GeocodingSearch.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = GeocodingSearch.mock.results
    results.append(specialResult)

    let clock = TestClock()

    let store = TestStore(initialState: Search.State(results: results)) {
      Search()
    } withDependencies: {
      $0.weatherClient.forecast = { _ in
        try await clock.sleep(for: .seconds(0))
        return .mock
      }
    }

    await store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    await store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    await clock.advance()
    await store.receive(.forecastResponse(42, .success(.mock))) {
      $0.resultForecastRequestInFlight = nil
      $0.weather = Search.State.Weather(
        id: 42,
        days: [
          Search.State.Weather.Day(
            date: Date(timeIntervalSince1970: 0),
            temperatureMax: 90,
            temperatureMaxUnit: "°F",
            temperatureMin: 70,
            temperatureMinUnit: "°F"
          ),
          Search.State.Weather.Day(
            date: Date(timeIntervalSince1970: 86_400),
            temperatureMax: 70,
            temperatureMaxUnit: "°F",
            temperatureMin: 50,
            temperatureMinUnit: "°F"
          ),
          Search.State.Weather.Day(
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

  func testTapOnLocationFailure() async {
    let results = GeocodingSearch.mock.results

    let store = TestStore(initialState: Search.State(results: results)) {
      Search()
    } withDependencies: {
      $0.weatherClient.forecast = { _ in throw SomethingWentWrong() }
    }

    await store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    await store.receive(.forecastResponse(1, .failure(SomethingWentWrong()))) {
      $0.resultForecastRequestInFlight = nil
    }
  }
}

private struct SomethingWentWrong: Equatable, Error {}
