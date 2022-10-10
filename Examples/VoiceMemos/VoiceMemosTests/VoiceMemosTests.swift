import Combine
import ComposableArchitecture
import XCTest
import XCTestDynamicOverlay

@testable import VoiceMemos

@MainActor
final class VoiceMemosTests: XCTestCase {
  let mainRunLoop = RunLoop.test

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
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    store.dependencies.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    store.dependencies.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)

    await store.send(.recordButtonTapped)
    await self.mainRunLoop.advance()
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    let recordingMemoTask = await store.send(.recordingMemo(.task))
    await self.mainRunLoop.advance(by: 1)
    await store.receive(.recordingMemo(.timerUpdated)) {
      $0.recordingMemo?.duration = 1
    }
    await self.mainRunLoop.advance(by: 1)
    await store.receive(.recordingMemo(.timerUpdated)) {
      $0.recordingMemo?.duration = 2
    }
    await self.mainRunLoop.advance(by: 0.5)
    await store.send(.recordingMemo(.stopButtonTapped)) {
      $0.recordingMemo?.mode = .encoding
    }
    await store.receive(.recordingMemo(.finalRecordingTime(2.5))) {
      $0.recordingMemo?.duration = 2.5
    }
    await store.receive(.recordingMemo(.audioRecorderDidFinish(.success(true))))
    try await store.receive(
      .recordingMemo(.delegate(.didFinish(.success(XCTUnwrap(store.state.recordingMemo)))))
    )
    {
      $0.recordingMemo = nil
      $0.voiceMemos = [
        VoiceMemo.State(
          date: Date(timeIntervalSince1970: 0),
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
    store.dependencies.mainRunLoop = .immediate
    store.dependencies.openSettings = { @MainActor in didOpenSettings = true }

    await store.send(.recordButtonTapped)
    await store.receive(.recordPermissionResponse(false)) {
      $0.alert = AlertState(title: TextState("Permission is required to record voice memos."))
      $0.audioRecorderPermission = .denied
    }
    await store.send(.alertDismissed) {
      $0.alert = nil
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
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    store.dependencies.temporaryDirectory = { URL(fileURLWithPath: "/tmp") }
    store.dependencies.uuid = .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)

    await store.send(.recordButtonTapped)
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.recordingMemo = RecordingMemo.State(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(fileURLWithPath: "/tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")
      )
    }
    let recordingMemoTask = await store.send(.recordingMemo(.task))

    didFinish.continuation.finish(throwing: SomeError())
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.recordingMemo(.audioRecorderDidFinish(.failure(SomeError()))))
    await store.receive(.recordingMemo(.delegate(.didFinish(.failure(SomeError()))))) {
      $0.alert = AlertState(title: TextState("Voice memo recording failed."))
      $0.recordingMemo = nil
    }

    await recordingMemoTask.cancel()
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
      try await self.mainRunLoop.sleep(for: 1.25)
      return true
    }
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    let task = await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(0.5))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.4)
    }
    await self.mainRunLoop.advance(by: 0.5)
    await store.receive(.voiceMemo(id: url, action: .timerUpdated(1))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.8)
    }
    await self.mainRunLoop.advance(by: 0.25)
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
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    let task = await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.failure(SomeError())))) {
      $0.alert = AlertState(title: TextState("Voice memo playback failed."))
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
    store.dependencies.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()

    await store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    await store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
    }
    await store.finish()
  }
}
