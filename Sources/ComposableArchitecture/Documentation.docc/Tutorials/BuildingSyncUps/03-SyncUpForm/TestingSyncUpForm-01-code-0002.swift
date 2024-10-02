import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct SyncUpFormTests {
  @Test
  func removeAttendee() async {
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
