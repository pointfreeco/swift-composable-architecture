import Combine
import ComposableArchitecture
import XCTest

@testable import VoiceMemos

class VoiceMemosTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testRecordMemoHappyPath() {
    // NB: Combine's concatenation behavior is different in 13.3
    guard #available(iOS 13.4, *) else { return }

    let audioRecorderSubject = PassthroughSubject<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >()

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioRecorderClient: .mock(
          currentTime: { _ in Effect(value: 2.5) },
          requestRecordPermission: { Effect(value: true) },
          startRecording: { _, _ in audioRecorderSubject.eraseToEffect() },
          stopRecording: { _ in
            .fireAndForget {
              audioRecorderSubject.send(.didFinishRecording(successfully: true))
              audioRecorderSubject.send(completion: .finished)
            }
          }
        ),
        date: { Date(timeIntervalSinceReferenceDate: 0) },
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        temporaryDirectory: { URL(fileURLWithPath: "/tmp") },
        uuid: { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }
      )
    )

    store.assert(
      .send(.recordButtonTapped),
      .do { self.scheduler.advance() },
      .receive(.recordPermissionBlockCalled(true)) {
        $0.audioRecorderPermission = .allowed
        $0.currentRecording = .init(
          date: Date(timeIntervalSinceReferenceDate: 0),
          mode: .recording,
          url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
        )
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.currentRecordingTimerUpdated) {
        $0.currentRecording!.duration = 1
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.currentRecordingTimerUpdated) {
        $0.currentRecording!.duration = 2
      },
      .do { self.scheduler.advance(by: 0.5) },
      .send(.recordButtonTapped) {
        $0.currentRecording!.mode = .encoding
      },
      .receive(.finalRecordingTime(2.5)) {
        $0.currentRecording!.duration = 2.5
      },
      .receive(.audioRecorderClient(.success(.didFinishRecording(successfully: true)))) {
        $0.currentRecording = nil
        $0.voiceMemos = [
          VoiceMemo(
            date: Date(timeIntervalSinceReferenceDate: 0),
            duration: 2.5,
            mode: .notPlaying,
            title: "",
            url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
          )
        ]
      }
    )
  }

  func testPermissionDenied() {
    var didOpenSettings = false

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioRecorderClient: .mock(
          requestRecordPermission: { Effect(value: false) }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        openSettings: .fireAndForget { didOpenSettings = true }
      )
    )

    store.assert(
      .send(.recordButtonTapped),
      .do { self.scheduler.advance() },
      .receive(.recordPermissionBlockCalled(false)) {
        $0.alert = .init(title: "Permission is required to record voice memos.")
        $0.audioRecorderPermission = .denied
      },
      .send(.alertDismissed) {
        $0.alert = nil
      },
      .send(.openSettingsButtonTapped),
      .do { XCTAssert(didOpenSettings) }
    )
  }

  func testRecordMemoFailure() {
    let audioRecorderSubject = PassthroughSubject<
      AudioRecorderClient.Action, AudioRecorderClient.Failure
    >()

    let store = TestStore(
      initialState: VoiceMemosState(),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioRecorderClient: .mock(
          currentTime: { _ in Effect(value: 2.5) },
          requestRecordPermission: { Effect(value: true) },
          startRecording: { _, _ in audioRecorderSubject.eraseToEffect() }
        ),
        date: { Date(timeIntervalSinceReferenceDate: 0) },
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        temporaryDirectory: { URL(fileURLWithPath: "/tmp") },
        uuid: { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")! }
      )
    )

    store.assert(
      .send(.recordButtonTapped),
      .do { self.scheduler.advance() },
      .receive(.recordPermissionBlockCalled(true)) {
        $0.audioRecorderPermission = .allowed
        $0.currentRecording = .init(
          date: Date(timeIntervalSinceReferenceDate: 0),
          mode: .recording,
          url: URL(string: "file:///tmp/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF.m4a")!
        )
      },
      .do { audioRecorderSubject.send(completion: .failure(.couldntActivateAudioSession)) },
      .receive(.audioRecorderClient(.failure(.couldntActivateAudioSession))) {
        $0.alert = .init(title: "Voice memo recording failed.")
        $0.currentRecording = nil
      }
    )
  }

  func testPlayMemoHappyPath() {
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 1,
            mode: .notPlaying,
            title: "",
            url: URL(string: "https://www.pointfree.co/functions")!
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioPlayerClient: .mock(
          play: { _, _ in
            Effect(value: .didFinishPlaying(successfully: true))
              .delay(for: 1, scheduler: self.scheduler)
              .eraseToEffect()
          }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.voiceMemo(index: 0, action: .playButtonTapped)) {
        $0.voiceMemos[0].mode = VoiceMemo.Mode.playing(progress: 0)
      },
      .do { self.scheduler.advance(by: 0.5) },
      .receive(VoiceMemosAction.voiceMemo(index: 0, action: VoiceMemoAction.timerUpdated(0.5))) {
        $0.voiceMemos[0].mode = .playing(progress: 0.5)
      },
      .do { self.scheduler.advance(by: 0.5) },
      .receive(VoiceMemosAction.voiceMemo(index: 0, action: VoiceMemoAction.timerUpdated(1))) {
        $0.voiceMemos[0].mode = .playing(progress: 1)
      },
      .receive(
        .voiceMemo(
          index: 0,
          action: .audioPlayerClient(.success(.didFinishPlaying(successfully: true)))
        )
      ) {
        $0.voiceMemos[0].mode = .notPlaying
      }
    )
  }

  func testPlayMemoFailure() {
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .notPlaying,
            title: "",
            url: URL(string: "https://www.pointfree.co/functions")!
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioPlayerClient: .mock(
          play: { _, _ in Effect(error: .decodeErrorDidOccur) }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.voiceMemo(index: 0, action: .playButtonTapped)) {
        $0.voiceMemos[0].mode = .playing(progress: 0)
      },
      .receive(.voiceMemo(index: 0, action: .audioPlayerClient(.failure(.decodeErrorDidOccur)))) {
        $0.alert = .init(title: "Voice memo playback failed.")
        $0.voiceMemos[0].mode = .notPlaying
      }
    )
  }

  func testStopMemo() {
    var didStopAudioPlayerClient = false

    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: URL(string: "https://www.pointfree.co/functions")!
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioPlayerClient: .mock(
          stop: { _ in .fireAndForget { didStopAudioPlayerClient = true } }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.voiceMemo(index: 0, action: .playButtonTapped)) {
        $0.voiceMemos[0].mode = .notPlaying
      },
      .do { XCTAssert(didStopAudioPlayerClient) }
    )
  }

  func testDeleteMemo() {
    var didStopAudioPlayerClient = false

    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 30,
            mode: .playing(progress: 0.3),
            title: "",
            url: URL(string: "https://www.pointfree.co/functions")!
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioPlayerClient: .mock(
          stop: { _ in .fireAndForget { didStopAudioPlayerClient = true } }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.voiceMemo(index: 0, action: .delete)) {
        $0.voiceMemos = []
        XCTAssertEqual(didStopAudioPlayerClient, true)
      }
    )
  }

  func testDeleteMemoWhilePlaying() {
    let store = TestStore(
      initialState: VoiceMemosState(
        voiceMemos: [
          VoiceMemo(
            date: Date(timeIntervalSinceNow: 0),
            duration: 10,
            mode: .notPlaying,
            title: "",
            url: URL(string: "https://www.pointfree.co/functions")!
          )
        ]
      ),
      reducer: voiceMemosReducer,
      environment: .mock(
        audioPlayerClient: .mock(
          play: { id, url in .future { _ in } },
          stop: { _ in .fireAndForget {} }
        ),
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.voiceMemo(index: 0, action: .playButtonTapped)) {
        $0.voiceMemos[0].mode = .playing(progress: 0)
      },
      .send(.voiceMemo(index: 0, action: .delete)) {
        $0.voiceMemos = []
      },
      .do { self.scheduler.run() }
    )
  }
}

extension VoiceMemosEnvironment {
  static func mock(
    audioPlayerClient: AudioPlayerClient = .mock(),
    audioRecorderClient: AudioRecorderClient = .mock(),
    date: @escaping () -> Date = { fatalError() },
    mainQueue: AnySchedulerOf<DispatchQueue>,
    openSettings: Effect<Never, Never> = .fireAndForget { fatalError() },
    temporaryDirectory: @escaping () -> URL = { fatalError() },
    uuid: @escaping () -> UUID = { fatalError() }
  ) -> Self {
    Self(
      audioPlayerClient: audioPlayerClient,
      audioRecorderClient: audioRecorderClient,
      date: date,
      mainQueue: mainQueue,
      openSettings: openSettings,
      temporaryDirectory: temporaryDirectory,
      uuid: uuid
    )
  }
}
