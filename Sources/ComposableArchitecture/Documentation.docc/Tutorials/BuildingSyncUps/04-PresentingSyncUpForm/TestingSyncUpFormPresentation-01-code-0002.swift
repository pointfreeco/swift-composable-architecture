import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp() async {
    let store = TestStore(initialState: SyncupsList.State()) {
      SyncUpsList()
    }
  }

  func testDeletion() async {
    // ...
  }
}
