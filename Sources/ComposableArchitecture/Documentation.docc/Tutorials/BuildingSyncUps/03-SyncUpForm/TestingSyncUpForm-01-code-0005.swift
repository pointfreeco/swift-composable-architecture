import ComposableArchitecture
import XCTest

@testable import SyncUps

class SyncUpFormTests: XCTestCase {
  @MainActor
  func testRemoveFocusedAttendee() async {
    let attendee1 = Attendee(id: Attendee.ID())
    let attendee2 = Attendee(id: Attendee.ID())
    let store = TestStore(
      initialState: SyncUpForm.State(
        focus: .attendee(attendee1.id),
        syncUp: SyncUp(
          id: SyncUp.ID(),
          attendees: [attendee1, attendee2]
        )
      )
    ) {
      SyncUpForm()
    }

    await store.send(.onDeleteAttendees([0])) {
      $0.focus = .attendee(attendee2.id)
      $0.syncUp.attendees = [attendee2]
    }
  }

  @MainActor
  func testRemoveAttendee() async {
    // ...
  }
}
