import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  @MainActor
  func testAddSyncUp() async {
    let store = TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID(0))
      )
    }

    await store.send(.addSyncUp(.presented(.set(<#property#>, <#value#>))))
  }

  @MainActor
  func testDeletion() async {
    // ...
  }
}
