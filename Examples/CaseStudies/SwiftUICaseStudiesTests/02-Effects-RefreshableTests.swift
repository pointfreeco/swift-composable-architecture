import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class RefreshableTests: XCTestCase {
  func testHappyPath() {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { Effect(value: "\($0) is a good number.") }
    store.environment.mainQueue = .immediate

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
      environment: .unimplemented
    )

    store.environment.fact.fetch = { _ in Effect(error: FactClient.Failure()) }
    store.environment.mainQueue = .immediate

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.failure(FactClient.Failure()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { Effect(value: "\($0) is a good number.") }
    store.environment.mainQueue = mainQueue.eraseToAnyScheduler()

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

extension RefreshableEnvironment {
  static let unimplemented = Self(
    fact: .unimplemented,
    mainQueue: .unimplemented
  )
}
