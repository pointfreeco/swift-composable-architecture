
import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  @MainActor
  func testAddAttendee() {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(id: SyncUp.ID())
      )
    ) {
      SyncUpForm()
    }
  }

  @MainActor
  func testRemoveFocusedAttendee() {
    // ...
  }

  @MainActor
  func testRemoveAttendee() {
    // ...
  }
}
