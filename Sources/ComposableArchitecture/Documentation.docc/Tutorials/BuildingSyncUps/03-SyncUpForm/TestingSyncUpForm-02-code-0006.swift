
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
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addAttendeeButtonTapped) {
      let attendee = Attendee(id: Attendee.ID())
      $0.focus = .attendee(attendee.id)
      $0.syncUp.attendees.append(attendee)
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
