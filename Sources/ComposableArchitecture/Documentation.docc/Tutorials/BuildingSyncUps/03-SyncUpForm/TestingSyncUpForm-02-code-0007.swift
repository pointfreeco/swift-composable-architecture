
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
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addAttendeeButtonTapped) {
      $0.focus = .attendee(Attendee.ID(0))
      $0.syncUp.attendees.append(Attendee(id: Attendee.ID(0)))
    }
  }

  func testRemoveFocusedAttendee() async {
    // ...
  }

  func testRemoveAttendee() async {
    // ...
  }
}
