import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class RefreshableTests: XCTestCase {
  func testHappyPath() {
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { .init(value: "\($0) is a good number.") },
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(/RefreshableAction.factResponse) {
      $0.isLoading = false
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() {
    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { _ in
          struct FactError: Error {} // TODO: Effect Unimplemented:Error helper?
          return .init(error: FactError())
        },
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(/RefreshableAction.factResponse) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: .init(),
      reducer: refreshableReducer,
      environment: .init(
        fact: .init { .init(value: "\($0) is a good number.") },
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
