import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpsListTests {
  @Test
  func addSyncUpNonExhaustive() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off

    await store.send(.addSyncUpButtonTapped)
  }
  
  @Test
  func addSyncUp() async {
    // ...
  }

  @Test
  func deletion() async {
    // ...
  }
}
