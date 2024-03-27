import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpDetailTests: XCTestCase {
  @MainActor
  func testDelete() async {
    let didDismiss = LockIsolated(false)
    defer { XCTAssertEqual(didDismiss.value, true) }

    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    } withDependencies: {
      $0.dismiss = DismissEffect { 
        didDismiss.setValue(true)
      }
    }

    await store.send(.deleteButtonTapped) {
      $0.destination = .alert(.deleteSyncUp)
    }
    await store.send(.destination(.presented(.alert(.confirmButtonTapped)))) {
      $0.destination = nil
    }
    await store.receive(\.delegate.deleteSyncUp, syncUp.id)
  }
  
  @MainActor
  func testEdit() async {
    // ...
  }
}
