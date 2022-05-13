import Combine
import ComposableArchitecture
import XCTest

@testable import VoiceMemos

class VoiceMemosTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testRecordMemoHappyPath() {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    let audioRecorderSubject = PassthroughSubject<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >()

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.currentTime) { Effect(value: 2.5) }
        .dependency(\.audioRecorder.requestRecordPermission) { Effect(value: true) }
        .dependency(\.audioRecorder.startRecording) { _ in audioRecorderSubject.eraseToEffect() }
        .dependency(\.audioRecorder.stopRecording) {
          .fireAndForget {
            audioRecorderSubject.send(.didFinishRecording(successfully: true))
            audioRecorderSubject.send(completion: .finished)
          }
        }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
        .dependency(\.temporaryDirectory) { URL(fileURLWithPath: "/tmp") }
        .dependency(\.uuid, .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!))
    )

    store.send(.recordButtonTapped)
    mainRunLoop.advance()
    store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
      )
    }
    mainRunLoop.advance(by: 1)
    store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording!.duration = 1
    }
    mainRunLoop.advance(by: 1)
    store.receive(.currentRecordingTimerUpdated) {
      $0.currentRecording!.duration = 2
    }
    mainRunLoop.advance(by: 0.5)
    store.send(.recordButtonTapped) {
      $0.currentRecording!.mode = .encoding
    }
    store.receive(.finalRecordingTime(2.5)) {
      $0.currentRecording!.duration = 2.5
    }
    store.receive(.audioRecorder(.success(.didFinishRecording(successfully: true)))) {
      $0.currentRecording = nil
      $0.voiceMemos = [
        .init(
          date: Date(timeIntervalSince1970: 0),
          duration: 2.5,
          mode: .notPlaying,
          title: "",
          url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
        )
      ]
    }
  }

  func testPermissionDenied() {
    var didOpenSettings = false

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.requestRecordPermission) { Effect(value: false) }
        .dependency(\.mainRunLoop, .immediate)
        .dependency(\.openSettings, .fireAndForget { didOpenSettings = true })
    )

    store.send(.recordButtonTapped)
    store.receive(.recordPermissionResponse(false)) {
      $0.alert = .init(title: .init("Permission is required to record voice memos."))
      $0.audioRecorderPermission = .denied
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
    store.send(.openSettingsButtonTapped)
    XCTAssert(didOpenSettings)
  }

  func testRecordMemoFailure() {
    let audioRecorderSubject = PassthroughSubject<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >()

    let store = _TestStore(
      initialState: .init(),
      reducer: VoiceMemos()
        .dependency(\.audioRecorder.currentTime) { Effect(value: 2.5) }
        .dependency(\.audioRecorder.requestRecordPermission) { Effect(value: true) }
        .dependency(\.audioRecorder.startRecording) { _ in audioRecorderSubject.eraseToEffect() }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
        .dependency(\.temporaryDirectory) { .init(fileURLWithPath: "/tmp") }
        .dependency(\.uuid, .constant(UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!))
    )

    store.send(.recordButtonTapped)
    self.mainRunLoop.advance(by: 0.5)
    store.receive(.recordPermissionResponse(true)) {
      $0.audioRecorderPermission = .allowed
      $0.currentRecording = .init(
        date: Date(timeIntervalSince1970: 0),
        mode: .recording,
        url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
      )
    }
    audioRecorderSubject.send(completion: .failure(.couldntActivateAudioSession))
    self.mainRunLoop.advance(by: 0.5)
    store.receive(.audioRecorder(.failure(.couldntActivateAudioSession))) {
      $0.alert = .init(title: .init("Voice memo recording failed."))
      $0.currentRecording = nil
    }
  }

  func testPlayMemoHappyPath() {
    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(timeIntervalSinceNow: 0),
            duration: 1,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in
          Effect(value: .didFinishPlaying(successfully: true))
            .delay(for: 1, scheduler: self.mainRunLoop)
            .eraseToEffect()
        }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    self.mainRunLoop.advance(by: 0.5)
    store.receive(.voiceMemo(id: url, action: .timerUpdated(0.5))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0.5)
    }
    self.mainRunLoop.advance(by: 0.5)
    store.receive(.voiceMemo(id: url, action: .timerUpdated(1))) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 1)
    }
    store.receive(
      .voiceMemo(
        id: url,
        action: .audioPlayerClient(.success(.didFinishPlaying(successfully: true)))
      )
    ) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testPlayMemoFailure() {
    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in Effect(error: .decodeErrorDidOccur) }
        .dependency(\.mainRunLoop, self.mainRunLoop.eraseToAnyScheduler())
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .playing(progress: 0)
    }
    store.receive(.voiceMemo(id: url, action: .audioPlayerClient(.failure(.decodeErrorDidOccur)))) {
      $0.alert = .init(title: .init("Voice memo playback failed."))
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
  }

  func testStopMemo() {
    var didStopAudioPlayerClient = false
    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.stop) { .fireAndForget { didStopAudioPlayerClient = true } }
    )

    store.send(.voiceMemo(id: url, action: .playButtonTapped)) {
      $0.voiceMemos[id: url]?.mode = .notPlaying
    }
    XCTAssert(didStopAudioPlayerClient)
  }

  func testDeleteMemo() {
    var didStopAudioPlayerClient = false
    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.stop) { .fireAndForget { didStopAudioPlayerClient = true } }
    )

    store.send(.voiceMemo(id: url, action: .delete)) {
      $0.voiceMemos = []
      XCTAssertNoDifference(didStopAudioPlayerClient, true)
    }
  }

  func testDeleteMemoWhilePlaying() {
    let url = URL(string: "https://www.pointfree.co/functions")!
    let store = _TestStore(
      initialState: .init(
        voiceMemos: [
          .init(
            date: Date(timeIntervalSinceNow: 0),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: url
          )
        ]
      ),
      reducer: VoiceMemos()
        .dependency(\.audioPlayer.play) { _ in .none }
        .dependency(\.audioPlayer.stop) { .none }
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
