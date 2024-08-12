import ComposableArchitecture
import XCTest

@testable import SyncUps

final class RecordMeetingTests: XCTestCase {
  func testTimer() async {
    let clock = TestClock()

    let store = await TestStore(
      initialState: RecordMeeting.State(
        syncUp: Shared(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(6)
          )
        )
      )
    ) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    }

    await store.send(.onTask)

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 0
      $0.secondsElapsed = 1
      XCTAssertEqual($0.durationRemaining, .seconds(5))
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 1
      $0.secondsElapsed = 2
      XCTAssertEqual($0.durationRemaining, .seconds(4))
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 1
      $0.secondsElapsed = 3
      XCTAssertEqual($0.durationRemaining, .seconds(3))
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 2
      $0.secondsElapsed = 4
      XCTAssertEqual($0.durationRemaining, .seconds(2))
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 2
      $0.secondsElapsed = 5
      XCTAssertEqual($0.durationRemaining, .seconds(1))
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.speakerIndex = 2
      $0.secondsElapsed = 6
      $0.syncUp.meetings.insert(
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: ""
        ),
        at: 0
      )
      XCTAssertEqual($0.durationRemaining, .seconds(0))
    }
  }

  @MainActor
  func testRecordTranscript() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: RecordMeeting.State(
        syncUp: Shared(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(6)
          )
        )
      )
    ) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream { continuation in
          continuation.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(formattedString: "I completed the project"),
              isFinal: true
            )
          )
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    }

    await store.send(.onTask)

    await store.receive(\.speechResult) {
      $0.transcript = "I completed the project"
    }

    await store.withExhaustivity(.off(showSkippedAssertions: true)) {
      await clock.advance(by: .seconds(6))
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
    }

    await store.assert {
      $0.syncUp.meetings[0].transcript = "I completed the project"
    }
  }

  func testEndMeetingSave() async {
    let clock = TestClock()

    let store = await TestStore(initialState: RecordMeeting.State(syncUp: Shared(.mock))) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    }

    await store.send(.onTask)

    await store.send(.endMeetingButtonTapped) {
      $0.alert = .endMeeting(isDiscardable: true)
    }

    await clock.advance(by: .seconds(3))
    await store.receive(\.timerTick)
    await store.receive(\.timerTick)
    await store.receive(\.timerTick)

    await store.send(\.alert.confirmSave) {
      $0.alert = nil
      $0.syncUp.meetings.insert(
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: ""
        ),
        at: 0
      )
    }
  }

  func testEndMeetingDiscard() async {
    let clock = TestClock()

    let store = await TestStore(initialState: RecordMeeting.State(syncUp: Shared(.mock))) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.speechClient.authorizationStatus = { .denied }
    }

    await store.send(.onTask)

    await store.send(.endMeetingButtonTapped) {
      $0.alert = .endMeeting(isDiscardable: true)
    }

    await store.send(\.alert.confirmDiscard) {
      $0.alert = nil
    }
  }

  func testNextSpeaker() async {
    let clock = TestClock()

    let store = await TestStore(
      initialState: RecordMeeting.State(
        syncUp: Shared(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(6)
          )
        )
      )
    ) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.speechClient.authorizationStatus = { .denied }
      $0.uuid = .incrementing
    }

    await store.send(.onTask)

    await store.send(.nextButtonTapped) {
      $0.speakerIndex = 1
      $0.secondsElapsed = 2
    }

    await store.send(.nextButtonTapped) {
      $0.speakerIndex = 2
      $0.secondsElapsed = 4
    }

    await store.send(.nextButtonTapped) {
      $0.alert = .endMeeting(isDiscardable: false)
    }

    await store.send(\.alert.confirmSave) {
      $0.alert = nil
      $0.syncUp.meetings.insert(
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: ""
        ),
        at: 0
      )
    }
  }

  func testSpeechRecognitionFailure_Continue() async {
    let clock = TestClock()

    let store = await TestStore(
      initialState: RecordMeeting.State(
        syncUp: Shared(
          SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
              Attendee(id: Attendee.ID()),
            ],
            duration: .seconds(6)
          )
        )
      )
    ) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream {
          $0.yield(
            SpeechRecognitionResult(
              bestTranscription: Transcription(formattedString: "I completed the project"),
              isFinal: true
            )
          )
          struct SpeechRecognitionFailure: Error {}
          $0.finish(throwing: SpeechRecognitionFailure())
        }
      }
      $0.uuid = .incrementing
    }

    await store.send(.onTask)

    await store.receive(\.speechResult) {
      $0.transcript = "I completed the project"
    }

    await store.receive(\.speechFailure) {
      $0.alert = .speechRecognizerFailed
      $0.transcript = "I completed the project ❌"
    }

    await store.send(\.alert.dismiss) {
      $0.alert = nil
    }

    await clock.advance(by: .seconds(6))

    await store.withExhaustivity(.off(showSkippedAssertions: true)) {
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
      await store.receive(\.timerTick)
    }
  }

  func testSpeechRecognitionFailure_Discard() async {
    let clock = TestClock()

    let store = await TestStore(initialState: RecordMeeting.State(syncUp: Shared(.mock))) {
      RecordMeeting()
    } withDependencies: {
      $0.continuousClock = clock
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream {
          struct SpeechRecognitionFailure: Error {}
          $0.finish(throwing: SpeechRecognitionFailure())
        }
      }
    }

    await store.send(.onTask)

    await store.receive(\.speechFailure) {
      $0.alert = .speechRecognizerFailed
    }

    await store.send(\.alert.confirmDiscard) {
      $0.alert = nil
    }
  }
}
