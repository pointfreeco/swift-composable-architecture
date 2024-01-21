import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp_NonExhaustive() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.addButtonTapped)

    let editedSyncUp = SyncUp(
      id: SyncUp.ID(UUID(0)),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr."),
      ],
      title: "Point-Free morning sync"
    )
    await store.send(.addSyncUp(.presented(.set(\.syncUp, editedSyncUp))))

    await store.send(.confirmAddButtonTapped) {
      $0.syncUps = [editedSyncUp]
    }
  }
  
  func testAddSyncUp() async {
    // ...
  }

  func testDeletion() async {
    // ...
  }
}
