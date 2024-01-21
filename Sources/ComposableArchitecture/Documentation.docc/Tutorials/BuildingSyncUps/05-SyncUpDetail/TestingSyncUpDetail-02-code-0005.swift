import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpDetailTests: XCTestCase {
  func testDelete() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(.destination(.presented(.alert(.confirmButtonTapped)))) {
      $0.destination = nil
    }
    await store.receive(\.delegate.deleteSyncUp, syncUp.id)
  }
  
  func testEdit() async {
    // ...
  }
}
