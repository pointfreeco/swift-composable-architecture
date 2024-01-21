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
    store.exhaustivity = .off
  }
  
  func testAddSyncUp() async {
    // ...
  }

  func testDeletion() async {
    // ...
  }
}
