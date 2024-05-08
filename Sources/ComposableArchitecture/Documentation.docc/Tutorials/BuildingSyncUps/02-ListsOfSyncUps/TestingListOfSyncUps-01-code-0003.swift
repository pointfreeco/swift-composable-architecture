import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpsListTests: XCTestCase {
  @MainActor
  func testDeletion() async {
    let store = TestStore(
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
