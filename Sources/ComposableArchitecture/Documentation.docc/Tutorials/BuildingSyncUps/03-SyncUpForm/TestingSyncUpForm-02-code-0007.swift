
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
      state.focus = .attendee(Attendee.ID(UUID(0)))
      state.syncUp.attendees.append(Attendee(id: Attendee.ID(UUID(0))))
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
