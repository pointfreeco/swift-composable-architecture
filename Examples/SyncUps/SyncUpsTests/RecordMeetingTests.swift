import ComposableArchitecture
import CustomDump
import XCTest
import Testing

@testable import SyncUps

@MainActor
@Suite
struct RecordMeetingTests2 {
  @Dependency(\.defaultDatabaseQueue) var databaseQueue
  @SharedReader([]) var syncUps: IdentifiedArrayOf<SyncUp>
  @SharedReader([]) var meetings: IdentifiedArrayOf<Meeting>

  init() async throws {
    try databaseQueue.migrate()
    _syncUps = try SharedReader(.syncUps)
    try await databaseQueue.write { db in
      try SyncUp(
        attendees: [
          Attendee(id: Attendee.ID()),
          Attendee(id: Attendee.ID()),
          Attendee(id: Attendee.ID()),
        ],
        seconds: 6
      )
      .insert(db)
    }
    _meetings = try SharedReader(.meetings(syncUpID: 1))
  }

  @Test
  func timer() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
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
      XCTAssertEqual($0.durationRemaining, .seconds(0))
    }

    expectNoDifference(
      meetings,
      [
        Meeting(
          id: 1,
          date: Date(timeIntervalSince1970: 1_234_567_890),
          syncUpID: 1,
          transcript: ""
        )
      ]
    )
  }

  @Test
  func nextSpeaker() async throws {
    let clock = TestClock()

    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
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
    }
    .finish()

    // TODO: Should we have SharedReader.assert?
    expectNoDifference(
      meetings,
      [
        Meeting(
          id: 1,
          date: Date(timeIntervalSince1970: 1_234_567_890),
          syncUpID: syncUps[0].id,
          transcript: ""
        )
      ]
    )
  }

  @Test
  func endMeetingDiscard() async {
    let clock = TestClock()

    let store = TestStore(initialState: RecordMeeting.State(syncUp: $syncUps[0])) {
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

    @SharedReader(.meetings(syncUpID: 1)) var meetings: IdentifiedArrayOf<Meeting> = []
    #expect(meetings == [])
  }

  @Test
  func speechRecognitionFailure_Continue() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
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
      for _ in 1...6 {
        await store.receive(\.timerTick)
      }
    }
  }

  @Test
  func recordTranscript() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
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

    expectNoDifference(
      meetings.first?.transcript,
      "I completed the project"
    )
  }

  @Test
  func endMeetingSave() async {
    let clock = TestClock()

    let store = await TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
    ) {
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
    }

    expectNoDifference(
      meetings,
      [
        Meeting(
          id: 1,
          date: Date(timeIntervalSince1970: 1_234_567_890),
          syncUpID: 1,
          transcript: ""
        )
      ]
    )
  }

  @Test
  func testSpeechRecognitionFailure_Discard() async {
    let clock = TestClock()

    let store = await TestStore(
      initialState: RecordMeeting.State(syncUp: $syncUps[0])
    ) {
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
