import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class RefreshableTests: XCTestCase {
  func testHappyPath() {
    let store = _TestStore(
      initialState: .init(),
      reducer: RefreshableReducer()
        .dependency(\.factClient, .init { .init(value: "\($0) is a good number.") })
        .dependency(\.mainQueue, .immediate)
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
    let store = _TestStore(
      initialState: .init(),
      reducer: RefreshableReducer()
        .dependency(\.factClient, .init { _ in .init(error: .init()) })
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.refresh) {
      $0.isLoading = true
    }
    store.receive(.factResponse(.failure(.init()))) {
      $0.isLoading = false
    }
  }

  func testCancellation() {
    let mainQueue = DispatchQueue.test

    let store = _TestStore(
      initialState: .init(),
      reducer: RefreshableReducer()
        .dependency(\.factClient, .init { .init(value: "\($0) is a good number.") })
        .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler())
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
