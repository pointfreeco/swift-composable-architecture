import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct RecordMeetingTests {
  @Test
  func timerFinishes() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr"),
      ],
      duration: .seconds(4),
      title: "Morning Sync"
    )
    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: Shared(value: syncUp))
    ) {
      RecordMeeting()
    }

    await store.send(.onAppear)
    // ❌ An effect returned for this action is still running. It must complete before the end of the test. …
    // ❌ Unimplemented: ContinuousClock.now …
    // ❌ Unimplemented: ContinuousClock.sleep …
  }
}
