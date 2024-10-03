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
  }
}
