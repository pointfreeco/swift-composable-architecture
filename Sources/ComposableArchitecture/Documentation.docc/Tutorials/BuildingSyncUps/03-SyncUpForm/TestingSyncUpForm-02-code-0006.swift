
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
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.addAttendeeButtonTapped) {
      let attendee = Attendee(id: Attendee.ID())
      state.focus = .attendee(attendee.id)
      state.syncUp.attendees.append(attendee)
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
