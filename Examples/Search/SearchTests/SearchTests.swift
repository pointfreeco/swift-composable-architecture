import Combine
import ComposableArchitecture
import XCTest

@testable import Search

@MainActor
class SearchTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testSearchAndClearQuery() async {
    let store = TestStore(
      initialState: .init(),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.search) { _ in .mock }
    )

    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await self.mainQueue.advance(by: 0.3)
    await store.receive(.searchResponse(.success(.mock))) {
      $0.results = Search.mock.results
    }
    store.send(.searchQueryChanged("")) {
      $0.results = []
      $0.searchQuery = ""
    }
  }

  func testSearchFailure() async {
    let store = TestStore(
      initialState: .init(),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.search) { _ in throw SomethingWentWrong() }
    )

    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await self.mainQueue.advance(by: 0.3)
    await store.receive(.searchResponse(.failure(SomethingWentWrong())))
  }

  func testClearQueryCancelsInFlightSearchRequest() async {
    let store = TestStore(
      initialState: .init(),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.search) { _ in .mock }
    )

    store.send(.searchQueryChanged("S")) {
      $0.searchQuery = "S"
    }
    await self.mainQueue.advance(by: 0.2)
    store.send(.searchQueryChanged("")) {
      $0.searchQuery = ""
    }
    await self.mainQueue.run()
  }

  func testTapOnLocation() async {
    let specialResult = Search.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = Search.mock.results
    results.append(specialResult)

    let store = TestStore(
      initialState: .init(results: results),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.forecast) { _ in .mock }
    )

    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    await self.mainQueue.advance()
    await store.receive(.forecastResponse(42, .success(.mock))) {
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

  func testTapOnLocationCancelsInFlightRequest() async {
    let specialResult = Search.Result(
      country: "Special Country",
      latitude: 0,
      longitude: 0,
      id: 42,
      name: "Special Place"
    )

    var results = Search.mock.results
    results.append(specialResult)

    let store = TestStore(
      initialState: .init(results: results),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.forecast) { _ in .mock }
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    store.send(.searchResultTapped(specialResult)) {
      $0.resultForecastRequestInFlight = specialResult
    }
    await self.mainQueue.advance()
    await store.receive(.forecastResponse(42, .success(.mock))) {
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

  func testTapOnLocationFailure() async {
    let results = Search.mock.results

    let store = TestStore(
      initialState: .init(results: results),
      reducer: SearchReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
        .dependency(\.weatherClient.forecast) { _ in throw SomethingWentWrong() }
    )

    store.send(.searchResultTapped(results.first!)) {
      $0.resultForecastRequestInFlight = results.first!
    }
    await self.mainQueue.advance()
    await store.receive(.forecastResponse(1, .failure(SomethingWentWrong()))) {
      $0.resultForecastRequestInFlight = nil
    }
  }
}

private struct SomethingWentWrong: Error {}
