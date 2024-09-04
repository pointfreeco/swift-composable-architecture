import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp() async {
    let store = await TestStore(initialState: SyncUpsList.State()) {
      SyncUpsList()
    }
  }

  func testDeletion() async {
    // ...
  }
}
