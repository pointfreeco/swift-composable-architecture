import ComposableArchitecture
import XCTest

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testTimer() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = true
    }
    await store.receive(.timerTick) {
      $0.count = 1
    }
    // ❌ Expected to receive an action, but received none after 0.1 seconds.
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }
}
