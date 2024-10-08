import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpsListTests {
  @Test
  func addSyncUp() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addSyncUpButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID(0))
      )
    }

    await store.send(\.addSyncUp.binding…)
  }

  @Test
  func deletion() async {
    // ...
  }
}
