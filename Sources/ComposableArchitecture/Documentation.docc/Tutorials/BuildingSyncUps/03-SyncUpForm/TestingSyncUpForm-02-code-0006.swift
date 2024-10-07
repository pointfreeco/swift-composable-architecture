import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpFormTests {
  @Test
  func addAttendee() async {
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

  @Test
  func removeFocusedAttendee() async {
    // ...
  }

  @Test
  func removeAttendee() async {
    // ...
  }
}
