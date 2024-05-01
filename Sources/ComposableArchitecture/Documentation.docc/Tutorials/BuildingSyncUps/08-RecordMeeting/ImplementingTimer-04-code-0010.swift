import ComposableArchitecture
import XCTest

@testable import SyncUps

final class RecordMeetingTests: XCTestCase {
  @MainActor
  func testTimerFinishes() async {
    let clock = TestClock()
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr"),
      ],
      duration: .duration(4),
      title: "Morning Sync"
    )
    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: Shared(syncUp))
    ) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
    }

    await store.send(.onAppear)
    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.secondsElapsed = 1
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 1
      $0.secondsElapsed = 2
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.secondsElapsed = 3
    }
  }
}
