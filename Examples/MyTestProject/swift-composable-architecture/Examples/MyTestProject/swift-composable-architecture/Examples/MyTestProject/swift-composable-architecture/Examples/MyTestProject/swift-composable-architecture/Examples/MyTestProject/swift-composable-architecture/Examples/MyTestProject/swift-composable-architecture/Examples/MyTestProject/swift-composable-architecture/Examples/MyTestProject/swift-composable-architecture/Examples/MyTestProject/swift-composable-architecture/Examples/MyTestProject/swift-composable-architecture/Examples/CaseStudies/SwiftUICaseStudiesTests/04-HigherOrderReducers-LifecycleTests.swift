import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class LifecycleTests: XCTestCase {
  func testLifecycle() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: LifecycleDemo.State(),
      reducer: LifecycleDemo()
    ) {
      $0.continuousClock = clock
    }

    await store.send(.toggleTimerButtonTapped) {
      $0.count = 0
    }

    await store.send(.timer(.onAppear))

    await clock.advance(by: .seconds(1))
    await store.receive(.timer(.wrapped(.tick))) {
      $0.count = 1
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.timer(.wrapped(.tick))) {
      $0.count = 2
    }

    await store.send(.timer(.wrapped(.incrementButtonTapped))) {
      $0.count = 3
    }

    await store.send(.timer(.wrapped(.decrementButtonTapped))) {
      $0.count = 2
    }

    await store.send(.toggleTimerButtonTapped) {
      $0.count = nil
    }

    await store.send(.timer(.onDisappear))
  }
}
