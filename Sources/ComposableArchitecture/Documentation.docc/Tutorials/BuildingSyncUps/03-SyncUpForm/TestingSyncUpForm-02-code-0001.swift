
import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpFormTests: XCTestCase {
  func testAddAttendee() {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID())
      )
    ) {
      SyncUpForm()
    }
  }

  func testRemoveFocusedAttendee() {
    // ...
  }

  func testRemoveAttendee() {
    // ...
  }
}
