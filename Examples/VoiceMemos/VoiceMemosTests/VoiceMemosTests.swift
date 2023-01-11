import ComposableArchitecture
import XCTest

@testable import VoiceMemos

@MainActor
final class VoiceMemosTests: XCTestCase {
  let clock = TestClock()

  func testRecordMemoHappyPath() async throws {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    )

    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()
    store.dependencies.audioRecorder.currentTime = { 2.5 }
    store.dependencies.audioRecorder.requestRecordPermission = { true }
    store.dependencies.audioRecorder.startRecording = { _ in
      try await didFinish.stream.first { _ in true }!
    }
    store.dependencies.audioRecorder.stopRecording = {
      didFinish.continuation.yield(true)
      didFinish.continuation.finish()
    }
    store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
    store.dependencies.continuousClock = self.clock
    store.dependencies.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    store.dependencies.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)

    await store.send(.recordButtonTapped)
    await self.clock.advance()
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.destination = .recordingMemo(
        RecordingMemo.State(
          date: Date(timeIntervalSinceReferenceDate: 0),
          mode: .recording,
          url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
        )
      )
    }
    let recordingMemoTask = await store.send(.destination(.presented(.recordingMemo(.task))))
    await self.clock.advance(by: .seconds(1))
    await store.receive(.destination(.presented(.recordingMemo(.timerUpdated)))) {
      try (/VoiceMemos.Destinations.State.recordingMemo).modify(&$0.destination) {
        $0.duration = 1
      }
    }
    await self.clock.advance(by: .seconds(1))
    await store.receive(.destination(.presented(.recordingMemo(.timerUpdated)))) {
      try (/VoiceMemos.Destinations.State.recordingMemo).modify(&$0.destination) {
        $0.duration = 2
      }
    }
    await self.clock.advance(by: .milliseconds(500))
    await store.send(.destination(.presented(.recordingMemo(.stopButtonTapped)))) {
      try (/VoiceMemos.Destinations.State.recordingMemo).modify(&$0.destination) {
        $0.mode = .encoding
      }
    }
    await store.receive(.destination(.presented(.recordingMemo(.finalRecordingTime(2.5))))) {
      try (/VoiceMemos.Destinations.State.recordingMemo).modify(&$0.destination) {
        $0.duration = 2.5
      }
    }
    await store.receive(
      .destination(.presented(.recordingMemo(.audioRecorderDidFinish(.success(true)))))
    )
    let currentMemo = try XCTUnwrap(
      store.state.destination,
      case: /VoiceMemos.Destinations.State.recordingMemo
    )
    await store.receive(
      .destination(.presented(.recordingMemo(.delegate(.didFinish(.success(currentMemo))))))
    ) {
      $0.destination = nil
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
    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    )

    var didOpenSettings = false

    store.dependencies.audioRecorder.requestRecordPermission = { false }
    store.dependencies.openSettings = { @MainActor in didOpenSettings = true }

    await store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(false)) {
      $0.destination = .alert(.permissionRequired)
      $0.audioRecorderPermission = .denied
    }
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
    await store.send(.openSettingsButtonTapped).finish()
    XCTAssert(didOpenSettings)
  }

  func testRecordMemoFailure() async {
    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    )

    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    store.dependencies.audioRecorder.currentTime = { 2.5 }
    store.dependencies.audioRecorder.requestRecordPermission = { true }
    store.dependencies.audioRecorder.startRecording = { _ in
      try await didFinish.stream.first { _ in true }!
    }
    store.dependencies.continuousClock = self.clock
    store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
    store.dependencies.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    store.dependencies.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)

    await store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.destination = .recordingMemo(
        RecordingMemo.State(
          date: Date(timeIntervalSinceReferenceDate: 0),
          mode: .recording,
          url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
        )
      )
    }
    let recordingMemoTask = await store.send(.destination(.presented(.recordingMemo(.task))))

    didFinish.continuation.finish(throwing: SomeError())
    await store.receive(.destination(.presented(.recordingMemo(.audioRecorderDidFinish(.failure(SomeError()))))))
    await store.receive(
      .destination(.presented(.recordingMemo(.delegate(.didFinish(.failure(SomeError()))))))
    ) {
      $0.destination = .alert(.recordingFailed)
    }

    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }

    await recordingMemoTask.cancel()
  }

  // Demonstration of how to write a non-exhaustive test for recording a memo and it failing to
  // record.
  func testRecordMemoFailure_NonExhaustive() async {
    // TODO: Flakey test. Would _withMainSerialExecutor work?

    let store = TestStore(
      initialState: VoiceMemos.State(),
      reducer: VoiceMemos()
    )
    store.exhaustivity = .off(showSkippedAssertions: true)

    struct SomeError: Error, Equatable {}
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    store.dependencies.audioRecorder.currentTime = { 2.5 }
    store.dependencies.audioRecorder.requestRecordPermission = { true }
    store.dependencies.audioRecorder.startRecording = { _ in
      try await didFinish.stream.first { _ in true }!
    }
    store.dependencies.continuousClock = self.clock
    store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
    store.dependencies.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    store.dependencies.uuid = .incrementing

    await store.send(.recordButtonTapped)

    await store.send(.destination(.presented(.recordingMemo(.task))))

    didFinish.continuation.finish(throwing: SomeError())
    await store.receive(
      .destination(.presented(.recordingMemo(.delegate(.didFinish(.failure(SomeError()))))))
    ) {
      $0.destination = .alert(.recordingFailed)
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
    )

    store.dependencies.audioPlayer.play = { _ in
      try await self.clock.sleep(for: .milliseconds(1_250))
      return true
    }
    store.dependencies.continuousClock = self.clock

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
    )

    struct SomeError: Error, Equatable {}

    store.dependencies.audioPlayer.play = { _ in throw SomeError() }
    store.dependencies.continuousClock = self.clock

    let task = await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.failure(SomeError())))) {
      $0.destination = .alert(.playbackFailed)
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
    )

    store.dependencies.audioPlayer.play = { _ in try await Task.never() }
    store.dependencies.continuousClock = self.clock

    await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
    await store.finish()
  }
}
