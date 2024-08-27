
import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  func testAddAttendee() async {
    let store = await TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID())
      )
    ) {
      SyncUpForm()
    }
  }

  func testRemoveFocusedAttendee() async {
    // ...
  }

  func testRemoveAttendee() async {
    // ...
  }
}
