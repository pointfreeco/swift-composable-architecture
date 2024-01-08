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
    await store.receive(\.timerTick) {
      $0.count = 1
    }
    // ✅ Test Suite 'Selected tests' passed at 2023-08-04 11:17:44.823.
    //        Executed 1 test, with 0 failures (0 unexpected) in 1.044 (1.046) seconds
    //    or:
    // ❌ Expected to receive an action, but received none after 0.1 seconds.
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }
}
