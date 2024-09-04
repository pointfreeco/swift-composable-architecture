import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  func testDeletion() async {
    let store = await TestStore(
      initialState: SyncUpsList.State(
        syncUps: [
          SyncUp(
            id: SyncUp.ID(),
            title: "Point-Free Morning Sync"
          )
        ]
      )
    ) {
      SyncUpsList()
    }

    await store.send(.onDelete([0]))
  }
}
