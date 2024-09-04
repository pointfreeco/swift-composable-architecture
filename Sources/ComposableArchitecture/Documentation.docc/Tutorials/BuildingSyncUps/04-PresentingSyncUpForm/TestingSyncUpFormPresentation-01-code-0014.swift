import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp() async {
    let store = await TestStore(initialState: SyncUpsList.State()) {
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
    await store.send(\.addSyncUp.binding.syncUp, editedSyncUp) {
      $0.addSyncUp?.syncUp = editedSyncUp
    }

    await store.send(.confirmAddButtonTapped) {
      $0.addSyncUp = nil
      $0.syncUps = [editedSyncUp]
    }
  }

  func testDeletion() async {
    // ...
  }
}
