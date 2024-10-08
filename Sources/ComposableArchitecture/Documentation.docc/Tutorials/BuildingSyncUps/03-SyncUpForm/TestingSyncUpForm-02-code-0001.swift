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
