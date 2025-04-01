import ComposableArchitecture
import Foundation
import Testing

@testable import VoiceMemos

let deadbeefID = UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!
let deadbeefURL = URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")

@MainActor
struct VoiceMemosTests {
  @Test
  func recordAndPlayback() async throws {
    let didFinish = AsyncThrowingStream.makeStream(of: Bool.self)
    // NB: We would prefer to use a test clock here, but due to testing async still being unreliable
    //     in Swift, we will use a real clock and sleep, instead.
    // let clock = TestClock()
    let store = TestStore(initialState: VoiceMemos.State()) {
      VoiceMemos()
    } withDependencies: {
      $0.audioPlayer.play = { @Sendable _ in
        try await Task.sleep(for: .milliseconds(2_500))
        return true
      }
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { @Sendable _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.audioRecorder.stopRecording = {
        didFinish.continuation.yield(true)
        didFinish.continuation.finish()
      }
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.continuousClock = ContinuousClock()
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(deadbeefID)
    }

    await store.send(.recordButtonTapped)
    await store.receive(\.recordPermissionResponse) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: deadbeefURL
      )
    }
    await store.send(\.recordingMemo.onTask)
    await store.send(\.recordingMemo.stopButtonTapped) {
      $0.recordingMemo?.mode = .encoding
    }
    await store.receive(\.recordingMemo.finalRecordingTime) {
      $0.recordingMemo?.duration = 2.5
    }
    await store.receive(\.recordingMemo.audioRecorderDidFinish.success)
    await store.receive(\.recordingMemo.delegate.didFinish.success) {
      $0.recordingMemo = nil
      $0.voiceMemos = [
        VoiceMemo.State(
          date: Date(timeIntervalSinceReferenceDate: 0),
          duration: 2.5,
          mode: .notPlaying,
          title: "",
          url: deadbeefURL
        )
      ]
    }
    await store.send(\.voiceMemos[id: deadbeefURL].playButtonTapped) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 0)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].delegate.playbackStarted)
    try await Task.sleep(for: .seconds(3))

    await store.receive(\.voiceMemos[id: deadbeefURL].timerUpdated) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 0.2)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].timerUpdated) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 0.4)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].timerUpdated) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 0.6)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].timerUpdated) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 0.8)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].timerUpdated) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .playing(progress: 1.0)
    }
    await store.receive(\.voiceMemos[id: deadbeefURL].audioPlayerClient.success) {
      $0.voiceMemos[id: deadbeefURL]?.mode = .notPlaying
    }
  }

  @Test
  func recordHappyPath() async throws {
    let didFinish = AsyncThrowingStream.makeStream(of: Bool.self)
    let clock = TestClock()
    let store = TestStore(initialState: VoiceMemos.State()) {
      VoiceMemos()
    } withDependencies: {
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { @Sendable _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.audioRecorder.stopRecording = {
        didFinish.continuation.yield(true)
        didFinish.continuation.finish()
      }
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.continuousClock = clock
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)
    }

    await store.send(.recordButtonTapped)
    await clock.advance()
    await store.receive(\.recordPermissionResponse) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    let recordingMemoTask = await store.send(\.recordingMemo.onTask)
    await clock.advance(by: .seconds(1))
    await store.receive(\.recordingMemo.timerUpdated) {
      $0.recordingMemo?.duration = 1
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.recordingMemo.timerUpdated) {
      $0.recordingMemo?.duration = 2
    }
    await clock.advance(by: .milliseconds(500))
    await store.send(\.recordingMemo.stopButtonTapped) {
      $0.recordingMemo?.mode = .encoding
    }
    await store.receive(\.recordingMemo.finalRecordingTime) {
      $0.recordingMemo?.duration = 2.5
    }
    await store.receive(\.recordingMemo.audioRecorderDidFinish.success)
    await store.receive(\.recordingMemo.delegate.didFinish.success) {
      $0.recordingMemo = nil
      $0.voiceMemos = [
        VoiceMemo.State(
          date: Date(timeIntervalSinceReferenceDate: 0),
          duration: 2.5,
          mode: .notPlaying,
          title: "",
          url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
        )
      ]
    }
    await recordingMemoTask.cancel()
  }

  @Test
  func permissionDenied() async {
    var didOpenSettings = false
    let store = TestStore(initialState: VoiceMemos.State()) {
      VoiceMemos()
    } withDependencies: {
      $0.audioRecorder.requestRecordPermission = { false }
      $0.openSettings = { @MainActor in didOpenSettings = true }
    }

    await store.send(.recordButtonTapped)
    await store.receive(\.recordPermissionResponse) {
      $0.alert = AlertState { TextState("Permission is required to record voice memos.") }
      $0.audioRecorderPermission = .denied
    }
    await store.send(\.alert.dismiss) {
      $0.alert = nil
    }
    await store.send(.openSettingsButtonTapped).finish()
    #expect(didOpenSettings)
  }

  @Test
  func recordFailure() async {
    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream.makeStream(of: Bool.self)
    let clock = TestClock()
    let store = TestStore(initialState: VoiceMemos.State()) {
      VoiceMemos()
    } withDependencies: {
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { @Sendable _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.continuousClock = clock
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(deadbeefID)
    }

    await store.send(.recordButtonTapped)
    await store.receive(\.recordPermissionResponse) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: deadbeefURL
      )
    }
    await store.send(\.recordingMemo.onTask)

    didFinish.continuation.finish(throwing: SomeError())
    await store.receive(\.recordingMemo.audioRecorderDidFinish.failure)
    await store.receive(\.recordingMemo.delegate.didFinish.failure) {
      $0.alert = AlertState { TextState("Voice memo recording failed.") }
      $0.recordingMemo = nil
    }
  }

  // Demonstration of how to write a non-exhaustive test for recording a memo and it failing to
  // record.
  @Test
  func recordFailureNonExhaustive() async {
    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream.makeStream(of: Bool.self)
    let clock = TestClock()
    let store = TestStore(initialState: VoiceMemos.State()) {
      VoiceMemos()
    } withDependencies: {
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { @Sendable _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.continuousClock = clock
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(deadbeefID)
    }
    await store.withExhaustivity(.off(showSkippedAssertions: true)) {
      await store.send(.recordButtonTapped)
      await store.send(\.recordingMemo.onTask)
      didFinish.continuation.finish(throwing: SomeError())
      await store.receive(\.recordingMemo.delegate.didFinish.failure) {
        $0.alert = AlertState { TextState("Voice memo recording failed.") }
        $0.recordingMemo = nil
      }
    }
  }

  @Test
  func playHappyPath() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let clock = TestClock()
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 1.25,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      )
    ) {
      VoiceMemos()
    } withDependencies: {
      $0.audioPlayer.play = { @Sendable _ in
        try await clock.sleep(for: .milliseconds(1_250))
        return true
      }
      $0.continuousClock = clock
    }

    await store.send(\.voiceMemos[id: url].playButtonTapped) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(\.voiceMemos[id: url].delegate.playbackStarted)
    await clock.advance(by: .milliseconds(500))
    await store.receive(\.voiceMemos[id: url].timerUpdated) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.4)
    }
    await clock.advance(by: .milliseconds(500))
    await store.receive(\.voiceMemos[id: url].timerUpdated) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.8)
    }
    await clock.advance(by: .milliseconds(250))
    await store.receive(\.voiceMemos[id: url].audioPlayerClient.success) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  @Test
  func playFailure() async {
    struct SomeError: Error, Equatable {}

    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let clock = TestClock()
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      )
    ) {
      VoiceMemos()
    } withDependencies: {
      $0.audioPlayer.play = { @Sendable _ in throw SomeError() }
      $0.continuousClock = clock
    }

    let task = await store.send(\.voiceMemos[id: url].playButtonTapped) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(\.voiceMemos[id: url].delegate.playbackStarted)
    await store.receive(\.voiceMemos[id: url].audioPlayerClient.failure) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await store.receive(\.voiceMemos[id: url].delegate.playbackFailed) {
      $0.alert = AlertState { TextState("Voice memo playback failed.") }
    }
    await task.cancel()
  }

  @Test
  func stop() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      )
    ) {
      VoiceMemos()
    }

    await store.send(\.voiceMemos[id: url].playButtonTapped) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  @Test
  func deleteOnly() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      )
    ) {
      VoiceMemos()
    }

    await store.send(.onDelete([0])) {
      $0.voiceMemos = []
    }
  }

  @Test
  func delete() async {
    let date = Date()
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: date,
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "Episode 1",
            url: URL(fileURLWithPath: "pointfreeco/1.m4a")
          ),
          VoiceMemo.State(
            date: date,
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "Episode 2",
            url: URL(fileURLWithPath: "pointfreeco/2.m4a")
          ),
          VoiceMemo.State(
            date: date,
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "Episode 3",
            url: URL(fileURLWithPath: "pointfreeco/3.m4a")
          ),
        ]
      )
    ) {
      VoiceMemos()
    }

    await store.send(.onDelete([1])) {
      $0.voiceMemos = [
        VoiceMemo.State(
          date: date,
          duration: 30,
          mode: .playing(progress: 0.3),
          title: "Episode 1",
          url: URL(fileURLWithPath: "pointfreeco/1.m4a")
        ),
        VoiceMemo.State(
          date: date,
          duration: 30,
          mode: .playing(progress: 0.3),
          title: "Episode 3",
          url: URL(fileURLWithPath: "pointfreeco/3.m4a")
        ),
      ]
    }
  }

  @Test
  func deleteWhilePlaying() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let clock = TestClock()
    let store = TestStore(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      )
    ) {
      VoiceMemos()
    } withDependencies: {
      $0.audioPlayer.play = { @Sendable _ in try await Task.never() }
      $0.continuousClock = clock
    }

    await store.send(\.voiceMemos[id: url].playButtonTapped) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(\.voiceMemos[id: url].delegate.playbackStarted)
    await store.send(.onDelete([0])) {
      $0.voiceMemos = []
    }
    await store.finish()
  }
}
