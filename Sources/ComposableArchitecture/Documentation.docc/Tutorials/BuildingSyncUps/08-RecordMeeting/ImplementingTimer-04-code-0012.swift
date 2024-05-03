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
    // ❌ An effect returned for this action is still running. It must complete before the end of the test. …
    // ❌ Unimplemented: @Dependency(\.date) …
    // ❌ @Dependency(\.uuid) has no test implementation, but was accessed from a test context:
    // ❌ A state change does not match expectation: …
    //    RecordMeeting.State(
    //        _alert: nil,
    //        _secondsElapsed: 6,
    //        _speakerIndex: 2,
    //        _syncUp: #1 SyncUp(
    //            id: Tagged(rawValue: UUID(A1EAB819-1283-4EDC-8492-ACBF231FAC0D)),
    //            attendees: […],
    //            duration: 6 seconds,
    //            meetings: [
    //                [0]: Meeting(
    //          −         id: Tagged(rawValue: UUID(00000000-0000-0000-0000-000000000000))
    //          +         id: Tagged(rawValue: UUID(E4299FB9-6B29-425D-93FE-23C7B9C8663B))
    //          −         date: Date(2009-02-13T23:31:30.000Z),
    //          +         date: Date(2024-05-01T18:09:15.218Z),
    //                    transcript: ""
    //                  )
    //              ],
    //            theme: .bubblegum,
    //            title: ""
    //          ),
    //        _transcript: ""
    //      )
    //
    //  (Expected: −, Actual: +)
  }
}
