import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  @MainActor
  func testAddSyncUp_NonExhaustive() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.addSyncUpButtonTapped)

    let editedSyncUp = SyncUp(
      id: SyncUp.ID(0),
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
  
  @MainActor
  func testAddSyncUp() async {
    // ...
  }

  @MainActor
  func testDeletion() async {
    // ...
  }
}
