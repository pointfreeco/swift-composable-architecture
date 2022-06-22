import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class RefreshableTests: XCTestCase {
  func testHappyPath() {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: RefreshableEnvironment(
        fact: FactClient(fetch: { Effect(value: "\($0) is a good number.") }),
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.success("1 is a good number."))) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: RefreshableEnvironment(
        fact: FactClient(fetch: { _ in Effect(error: FactClient.Error()) }),
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.failure(FactClient.Error()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: RefreshableEnvironment(
        fact: FactClient(fetch: { Effect(value: "\($0) is a good number.") }),
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.send(.cancelButtonTapped) {
      $0.isLoading = false
    }
  }
}
