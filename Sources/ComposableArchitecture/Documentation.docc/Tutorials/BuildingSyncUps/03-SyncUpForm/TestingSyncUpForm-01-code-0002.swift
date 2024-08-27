import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  func testRemoveAttendee() async {
    let store = await TestStore(
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
