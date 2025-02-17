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

    let editedSyncUp = SyncUp(
      id: SyncUp.ID(0),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr."),
      ],
      title: "Point-Free morning sync"
    )
    await store.send(.addSyncUp(.presented(.set(\.syncUp, editedSyncUp)))) {
      $0.addSyncUp?.syncUp = editedSyncUp
    }

    await store.send(.confirmAddButtonTapped) {
      $0.addSyncUp = nil
      $0.$syncUps.withLock { $0 = [editedSyncUp] }
    }
  }

  @Test
  func deletion() async {
    @Shared(.syncUps) var syncUps = [
      SyncUp(
        id: SyncUp.ID(),
        title: "Point-Free Morning Sync"
      )
    ]
    let store = TestStore(
      initialState: SyncUpsList.State()
    ) {
      SyncUpsList()
    }

    await store.send(.onDelete([0])) {
      $0.$syncUps.withLock { $0 = [] }
    }
  }
}
