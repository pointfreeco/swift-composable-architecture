import Combine
import ComposableArchitecture
import XCTest

@testable import VoiceMemos

@MainActor
class VoiceMemosTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testRecordMemoHappyPath() async {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    // TODO: CancellableAsyncValue instead of AsyncStream with first?
    let didFinish = AsyncThrowingStream<Bool, Error>.streamWithContinuation()

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.currentTime) { 2.5 }
        .dependency(\.audioRecorder.requestRecordPermission) { true }
        .dependency(\.audioRecorder.startRecording) { _ in
          try await didFinish.stream.first { _ in true }!
        }
        .dependency(\.audioRecorder.stopRecording) {
          didFinish.continuation.yield(true)
          didFinish.continuation.finish()
        }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
        .dependency(\.temporaryDirectory) { URL(fileURLWithPath: "/tmp") }
        .dependency(\.uuid, .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!))
    )

    let recordButtonTappedTask = store.send(.recordButtonTapped)
    await self.mainRunLoop.advance()
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
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
        .init(
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

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.requestRecordPermission) { false }
        .dependency(\.mainRunLoop, .immediate)
        .dependency(\.openSettings) { await didOpenSettings.set(true) }
    )

    store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(false)) {
      $0.alert = .init(title: .init("Permission is required to record voice memos."))
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

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.currentTime) { 2.5 }
        .dependency(\.audioRecorder.requestRecordPermission) { true }
        .dependency(\.audioRecorder.startRecording) { _ in
          try await didFinish.stream.first { _ in true }!
        }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
        .dependency(\.temporaryDirectory) { URL(fileURLWithPath: "/tmp") }
        .dependency(\.uuid, .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!))
    )

    store.send(.recordButtonTapped)
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    didFinish.continuation.finish(throwing: AudioRecorderClient.Failure.couldntActivateAudioSession)
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.audioRecorderDidFinish(.failure(AudioRecorderClient.Failure.couldntActivateAudioSession))) {
      $0.alert = .init(title: .init("Voice memo recording failed."))
      $0.currentRecording = nil
    }
  }

  func testPlayMemoHappyPath() async {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(),
            duration: 1,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in
          try await self.mainRunLoop.sleep(for: 1)
          return true
        }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
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
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in throw AudioPlayerClient.Failure.decodeErrorDidOccur }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
    )

    let task = store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(
      .voiceMemo(
        id: url, action: .audioPlayerClient(.failure(AudioPlayerClient.Failure.decodeErrorDidOccur))
      )
    ) {
      $0.alert = .init(title: .init("Voice memo playback failed."))
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    await task.cancel()
  }

  func testStopMemo() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
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

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testDeleteMemo() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
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

    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }

  func testDeleteMemoWhilePlaying() {
    let url = URL(fileURLWithPath: "pointfreeco/functions.m4a")
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in try await Task.never() }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
  }
}
