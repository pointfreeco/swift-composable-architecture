import ComposableArchitecture
import Testing

@testable import CounterApp

@MainActor
struct CounterFeatureTests {
  @Test
  func basics() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }
}
