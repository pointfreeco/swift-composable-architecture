import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpDetailTests {
  @Test
  func edit() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(value: syncUp))) {
      SyncUpDetail()
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }

    var editedSyncUp = syncUp
    editedSyncUp.title = "Point-Free Evening Sync"
    await store.send(\.destination.edit.binding.syncUp, editedSyncUp) {
      $0.destination?.edit?.syncUp = editedSyncUp
    }
  }
}
