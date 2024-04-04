
import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  @MainActor
  func testAddAttendee() async {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID())
      )
    ) {
      SyncUpForm()
    }
  }

  @MainActor
  func testRemoveFocusedAttendee() async {
    // ...
  }

  @MainActor
  func testRemoveAttendee() async {
    // ...
  }
}
