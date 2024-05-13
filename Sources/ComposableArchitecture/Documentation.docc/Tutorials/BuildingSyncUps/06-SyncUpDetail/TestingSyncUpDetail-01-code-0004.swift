import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpDetailTests: XCTestCase {
  @MainActor
  func testEdit() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: Shared(syncUp))) {
      SyncUpDetail()
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }

    var editedSyncUp = syncUp
    editedSyncUp.title = "Point-Free Evening Sync"
    await store.send(\.destination.edit.binding.syncUp, editedSyncUp) {

    }
  }
}
