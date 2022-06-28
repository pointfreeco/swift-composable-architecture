import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LifecycleTests: XCTestCase {
  func testLifecycle() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: LifecycleDemoState(),
      reducer: lifecycleDemoReducer,
      environment: LifecycleDemoEnvironment(
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.toggleTimerButtonTapped) {
      $0.count = 0
    }

    store.send(.timer(.onAppear))

    mainQueue.advance(by: .seconds(1))
    store.receive(.timer(.action(.tick))) {
      $0.count = 1
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.timer(.action(.tick))) {
      $0.count = 2
    }

    store.send(.timer(.action(.incrementButtonTapped))) {
      $0.count = 3
    }

    store.send(.timer(.action(.decrementButtonTapped))) {
      $0.count = 2
    }

    store.send(.toggleTimerButtonTapped) {
      $0.count = nil
    }

    store.send(.timer(.onDisappear))
  }
}
