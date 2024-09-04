import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp() async {
    let store = await TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    }

    await store.send(.addSyncUpButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(syncUp: SyncUp(id: SyncUp.ID()))
    }
  }

  func testDeletion() async {
    // ...
  }
}
