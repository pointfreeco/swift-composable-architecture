import ComposableArchitecture
import XCTest

@testable import SyncUps

final class RecordMeetingTests: XCTestCase {
  func testTimerFinishes() async {
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr"),
      ],
      duration: .seconds(4),
      title: "Morning Sync"
    )
    let store = await TestStore(
      initialState: RecordMeeting.State(syncUp: Shared(syncUp))
    ) {
      RecordMeeting()
    }

    await store.send(.onAppear)
  }
}
