import ComposableArchitecture
import XCTest

@testable import VoiceMemos

@MainActor
final class VoiceMemosTests: XCTestCase {
  let clock = TestClock()

  func testRecordMemoHappyPath() async throws {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    ) {
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.audioRecorder.stopRecording = {
        didFinish.continuation.yield(true)
        didFinish.continuation.finish()
      }
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.continuousClock = self.clock
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)
    }

    await store.send(.recordButtonTapped)
    await self.clock.advance()
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    let recordingMemoTask = await store.send(.recordingMemo(.task))
    await self.clock.advance(by: .seconds(1))
    await store.receive(.recordingMemo(.timerUpdated)) {
      $0.recordingMemo?.duration = 1
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(.recordingMemo(.timerUpdated)) {
      $0.recordingMemo?.duration = 2
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.send(.recordingMemo(.stopButtonTapped)) {
      $0.recordingMemo?.mode = .encoding
    }
    await store.receive(.recordingMemo(.finalRecordingTime(2.5))) {
      $0.recordingMemo?.duration = 2.5
    }
    await store.receive(.recordingMemo(.audioRecorderDidFinish(.success(true))))
    try await store.receive(
      .recordingMemo(.delegate(.didFinish(.success(XCTUnwrap(store.state.recordingMemo)))))
    ) {
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

  func testPermissionDenied() async {
    var didOpenSettings = false
    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    ) {
      $0.audioRecorder.requestRecordPermission = { false }
      $0.openSettings = { @MainActor in didOpenSettings = true }
    }

    await store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(false)) {
      $0.alert = AlertState { TextState("Permission is required to record voice memos.") }
      $0.audioRecorderPermission = .denied
    }
    await store.send(.alertDismissed) {
      $0.alert = nil
    }
    await store.send(.openSettingsButtonTapped).finish()
    XCTAssert(didOpenSettings)
  }

  func testRecordMemoFailure() async {
    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    ) {
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.continuousClock = self.clock
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)
    }

    await store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSinceReferenceDate: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    let recordingMemoTask = await store.send(.recordingMemo(.task))

    didFinish.continuation.finish(throwing: SomeError())
    await store.receive(.recordingMemo(.audioRecorderDidFinish(.failure(SomeError()))))
    await store.receive(.recordingMemo(.delegate(.didFinish(.failure(SomeError()))))) {
      $0.alert = AlertState { TextState("Voice memo recording failed.") }
      $0.recordingMemo = nil
    }

    await recordingMemoTask.cancel()
  }

  // Demonstration of how to write a non-exhaustive test for recording a memo and it failing to
  // record.
  func testRecordMemoFailure_NonExhaustive() async {
    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    ) {
      $0.audioRecorder.currentTime = { 2.5 }
      $0.audioRecorder.requestRecordPermission = { true }
      $0.audioRecorder.startRecording = { _ in
        try await didFinish.stream.first { _ in true }!
      }
      $0.continuousClock = self.clock
      $0.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
      $0.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
      $0.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.recordButtonTapped)
    await store.send(.recordingMemo(.task))
    didFinish.continuation.finish(throwing: SomeError())
    await store.receive(.recordingMemo(.delegate(.didFinish(.failure(SomeError()))))) {
      $0.alert = AlertState { TextState("Voice memo recording failed.") }
      $0.recordingMemo = nil
    }
  }

  func testPlayMemoHappyPath() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
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
      ),
      reducer: VoiceMemos()
    ) {
      $0.audioPlayer.play = { _ in
        try await self.clock.sleep(for: .milliseconds(1_250))
        return true
      }
      $0.continuousClock = self.clock
    }

    let task = await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(0.5))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.4)
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(1))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.8)
    }
    await self.clock.advance(by: .milliseconds(250))
    await store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.success(true)))) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await task.cancel()
  }

  func testPlayMemoFailure() async {
    struct SomeError: Error, Equatable {}

    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
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
      ),
      reducer: VoiceMemos()
    ) {
      $0.audioPlayer.play = { _ in throw SomeError() }
      $0.continuousClock = self.clock
    }

    let task = await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.failure(SomeError())))) {
      $0.alert = AlertState { TextState("Voice memo playback failed.") }
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await task.cancel()
  }

  func testStopMemo() async {
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
      ),
      reducer: VoiceMemos()
    )

    await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testDeleteMemo() async {
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
      ),
      reducer: VoiceMemos()
    )

    await store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }

  func testDeleteMemoWhilePlaying() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")

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
      ),
      reducer: VoiceMemos()
    ) {
      $0.audioPlayer.play = { _ in try await Task.never() }
      $0.continuousClock = self.clock
    }

    await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
    await store.finish()
  }
}
