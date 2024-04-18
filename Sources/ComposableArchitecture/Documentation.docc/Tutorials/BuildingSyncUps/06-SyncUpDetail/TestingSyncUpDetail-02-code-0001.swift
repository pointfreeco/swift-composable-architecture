import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpDetailTests: XCTestCase {
  @MainActor
  func testDelete() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      title: "Point-Free Morning Sync"
    )
    let store = TestStore(initialState: SyncUpDetail.State(syncUp: syncUp)) {
      SyncUpDetail()
    }
  }
  
  @MainActor
  func testEdit() async {
    // ...
  }
}
