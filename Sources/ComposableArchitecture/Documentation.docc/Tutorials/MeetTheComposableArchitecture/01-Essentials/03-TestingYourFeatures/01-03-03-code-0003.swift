import ComposableArchitecture
import Testing

@testable import CounterApp

@MainActor
struct CounterFeatureTests {
  @Test
  func numberFact() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    // ❌ An effect returned for this action is still running.
    //    It must complete before the end of the test. …
  }
}
