import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpDetailTests {
  @Test
  func delete() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(syncUp))) {
      SyncUpDetail()
    } withDependencies: {
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(.destination(.presented(.alert(.confirmButtonTapped)))) {
      $0.destination = nil
    }
    await store.receive(\.delegate.deleteSyncUp, syncUp.id)
  }

  @Test
  func edit() async {
    // ...
  }
}
