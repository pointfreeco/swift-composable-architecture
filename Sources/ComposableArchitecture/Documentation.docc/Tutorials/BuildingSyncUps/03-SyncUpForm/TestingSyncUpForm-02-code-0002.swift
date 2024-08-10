
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

    await store.send(.addAttendeeButtonTapped) {
      let attendee = Attendee(id: Attendee.ID())
      $0.focus = .attendee(attendee.id)
      $0.syncUp.attendees.append(attendee)
    }
  }

  func testRemoveFocusedAttendee() async {
    // ...
  }

  func testRemoveAttendee() async {
    // ...
  }
}
