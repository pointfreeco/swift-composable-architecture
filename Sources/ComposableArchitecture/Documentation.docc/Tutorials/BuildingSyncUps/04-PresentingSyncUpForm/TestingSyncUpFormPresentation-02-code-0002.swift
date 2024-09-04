import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp_NonExhaustive() async {
    let store = await TestStore(initialState: SyncUpsList.State()) {
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
