import ComposableArchitecture
import Testing

@testable import CounterApp

@MainActor
struct CounterFeatureTests {
  @Test
  func timer() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = true
    }
    await store.receive(\.timerTick) {
      $0.count = 1
    }
    // ✅ Test Suite 'Selected tests' passed.
    //        Executed 1 test, with 0 failures (0 unexpected) in 1.044 (1.046) seconds
    //    or:
    // ❌ Expected to receive an action, but received none after 0.1 seconds.
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }
}
