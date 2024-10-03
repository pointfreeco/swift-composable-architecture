import ComposableArchitecture
import Testing

@testable import CounterApp

@MainActor
struct AppFeatureTests {
  @Test
  func incrementInFirstTab() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }
  }
}
