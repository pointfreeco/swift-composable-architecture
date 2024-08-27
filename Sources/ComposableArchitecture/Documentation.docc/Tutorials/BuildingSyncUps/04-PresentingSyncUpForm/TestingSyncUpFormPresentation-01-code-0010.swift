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

    await store.send(\.addSyncUp.binding…)
  }

  func testDeletion() async {
    // ...
  }
}
