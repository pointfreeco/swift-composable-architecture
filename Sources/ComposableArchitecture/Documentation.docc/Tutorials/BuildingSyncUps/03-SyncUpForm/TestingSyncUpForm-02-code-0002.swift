
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

    await store.send(.addAttendeeButtonTapped) {
      let attendee = Attendee(id: Attendee.ID())
      state.focus = .attendee(attendee.id)
      state.syncUp.attendees.append(attendee)
    }
  }

  func testRemoveFocusedAttendee() {
    // ...
  }

  func testRemoveAttendee() {
    // ...
  }
}
