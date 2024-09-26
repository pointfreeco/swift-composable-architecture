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
    // ❌ An effect returned for this action is still running.
    //    It must complete before the end of the test. …
  }
}
