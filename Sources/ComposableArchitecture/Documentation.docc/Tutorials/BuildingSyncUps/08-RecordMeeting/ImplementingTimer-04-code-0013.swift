import ComposableArchitecture
import Testing

@testable import SyncUps

@MainActor
struct RecordMeetingTests {
  @Test
  func timerFinishes() async {
    let clock = TestClock()
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
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.uuid = .incrementing
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

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.secondsElapsed = 4
      $0.syncUp.meetings.insert(
        Meeting(
          id: UUID(0),
          date: Date(timeIntervalSince1970: 1234567890),
          transcript: ""
        ),
        at: 0
      )
    }
  }
}
