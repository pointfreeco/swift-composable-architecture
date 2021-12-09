import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class RefreshableTests: XCTestCase {
  func testHappyPath() async {
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { "\($0) is a good number." },
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.success("1 is a good number."))) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() async {
    struct FactError: Error {}
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { _ in throw FactError() },
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.failure(FactError()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { "\($0) is a good number." },
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
