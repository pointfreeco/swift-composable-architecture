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
    
    await store.send(.incrementButtonTapped)
    await store.send(.decrementButtonTapped)
  }
}
