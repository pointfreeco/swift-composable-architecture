import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class RefreshableTests: XCTestCase {
  func testHappyPath() async {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { "\($0) is a good number." }
    store.environment.mainQueue = .immediate

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.success("1 is a good number."))) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() async {
    struct FactError: Equatable, Error {}
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { _ in throw FactError() }
    store.environment.mainQueue = .immediate

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.failure(FactError()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let store = TestStore(
      initialState: RefreshableState(),
      reducer: refreshableReducer,
      environment: .unimplemented
    )

    store.environment.fact.fetch = { "\($0) is a good number." }

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
