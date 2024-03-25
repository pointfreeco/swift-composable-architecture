import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpDetailTests: XCTestCase {
  @MainActor
  func testEdit() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    }

    await store.send(.editButtonTapped) {
      $0.destination = .edit(SyncUpForm.State(syncUp: syncUp))
    }
  }
}
