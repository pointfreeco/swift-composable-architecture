import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpFormTests: XCTestCase {
  func testRemoveAttendee() {
    let store = TestStore(
      initialState: SyncUpForm.State(
        syncUp: SyncUp(
          id: SyncUp.ID(),
          attendees: [
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID())
          ]
        )
      )
    ) {
      SyncUpForm()
    }
  }
}
