import Combine
import ComposableArchitecture
import XCTest
import XCTestDynamicOverlay

@testable import VoiceMemos

@MainActor
class VoiceMemosTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testRecordMemoHappyPath() async {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    // TODO: CancellableAsyncValue instead of AsyncStream with first?
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioRecorder.currentTime = { 2.5 }
    environment.audioRecorder.requestRecordPermission = { true }
    environment.audioRecorder.startRecording = { _ in
      try await didFinish.stream.first { _ in true }!
    }
    environment.audioRecorder.stopRecording = {
      didFinish.continuation.yield(true)
      didFinish.continuation.finish()
    }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    environment.uuid = { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
    )

    let recordButtonTappedTask = store.send(.recordButtonTapped)
    await self.mainRunLoop.advance()
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = VoiceMemosState.CurrentRecording(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    await self.mainRunLoop.advance(by: 1)
    await store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording?.duration = 1
    }
    await self.mainRunLoop.advance(by: 1)
    await store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording?.duration = 2
    }
    await self.mainRunLoop.advance(by: 0.5)
    store.send(.recordButtonTapped) {
      $0.currentRecording?.mode = .encoding
    }
    await store.receive(.finalRecordingTime(2.5)) {
      $0.currentRecording?.duration = 2.5
    }
    await store.receive(.audioRecorderDidFinish(.success(true))) {
      $0.currentRecording = nil
      $0.voiceMemos = [
        VoiceMemo(
          date: Date(timeIntervalSince1970: 0),
          duration: 2.5,
          mode: .notPlaying,
          title: "",
          url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
        )
      ]
    }
    await recordButtonTappedTask.finish()
  }

  func testPermissionDenied() async {
    let didOpenSettings = SendableState(false)

    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioRecorder.requestRecordPermission = { false }
    environment.mainRunLoop = .immediate
    environment.openSettings = { await didOpenSettings.set(true) }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(false)) {
      $0.alert = AlertState(title: TextState("Permission is required to record voice memos."))
      $0.audioRecorderPermission = .denied
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
    await store.send(.openSettingsButtonTapped).finish()
    let didOpen = await didOpenSettings.value
    XCTAssert(didOpen)
  }

  func testRecordMemoFailure() async {
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioRecorder.currentTime = { 2.5 }
    environment.audioRecorder.requestRecordPermission = { true }
    environment.audioRecorder.startRecording = { _ in
      try await didFinish.stream.first { _ in true }!
    }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    environment.uuid = { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.recordButtonTapped)
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = VoiceMemosState.CurrentRecording(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    didFinish.continuation.finish(throwing: AudioRecorderClient.Failure.couldntActivateAudioSession)
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(
      .audioRecorderDidFinish(.failure(AudioRecorderClient.Failure.couldntActivateAudioSession))
    ) {
      $0.alert = AlertState(title: TextState("Voice memo recording failed."))
      $0.currentRecording = nil
    }
  }

  func testPlayMemoHappyPath() async {
    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioPlayer.play = { _ in
      try await self.mainRunLoop.sleep(for: 1)
      return true
    }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(),
            duration: 1,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
    )

    let task = store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(0.5))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.5)
    }
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(1))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 1)
    }
    await store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.success(true)))) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await task.cancel()
  }

  func testPlayMemoFailure() async {
    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioPlayer.play = { _ in throw AudioPlayerClient.Failure.decodeErrorDidOccur }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
    )

    let task = store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(
      .voiceMemo(
        id: url, action: .audioPlayerClient(.failure(AudioPlayerClient.Failure.decodeErrorDidOccur))
      )
    ) {
      $0.alert = AlertState(title: TextState("Voice memo playback failed."))
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await task.cancel()
  }

  func testStopMemo() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .unimplemented
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testDeleteMemo() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .unimplemented
    )

    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }

  func testDeleteMemoWhilePlaying() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    var environment = VoiceMemosEnvironment.unimplemented
    environment.audioPlayer.play = { _ in try await Task.never() }
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: environment
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }
}

extension VoiceMemosEnvironment {
  static let unimplemented = Self(
    audioPlayer: .unimplemented,
    audioRecorder: .unimplemented,
    mainRunLoop: .unimplemented,
    openSettings: XCTUnimplemented("\(Self.self).openSettings"),
    temporaryDirectory: XCTUnimplemented(
      "\(Self.self).temporaryDirectory",
      placeholder: URL(fileURLWithPath: NSTemporaryDirectory())
    ),
    uuid: XCTUnimplemented("\(Self.self).uuid", placeholder: UUID())
  )
}
