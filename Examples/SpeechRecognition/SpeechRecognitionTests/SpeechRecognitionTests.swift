import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = PassthroughSubject<SpeechClient.Action, SpeechClient.Error>()
  let scheduler = DispatchQueue.testScheduler

  func testDenyAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          requestAuthorization: { Effect(value: .denied) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },
      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
        $0.alert = .init(
          title: """
            You denied access to speech recognition. This app needs access to transcribe your speech.
            """
        )
        $0.isRecording = false
        $0.speechRecognizerAuthorizationStatus = .denied
      }
    )
  }

  func testRestrictedAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          requestAuthorization: { Effect(value: .restricted) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },
      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
        $0.alert = .init(title: "Your device does not allow speech recognition.")
        $0.isRecording = false
        $0.speechRecognizerAuthorizationStatus = .restricted
      }
    )
  }

  func testAllowAndRecord() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          finishTask: { _ in
            .fireAndForget { self.recognitionTaskSubject.send(completion: .finished) }
          },
          recognitionTask: { _, _ in self.recognitionTaskSubject.eraseToEffect() },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    let result = SpeechRecognitionResult(
      bestTranscription: Transcription(
        averagePauseDuration: 0.1,
        formattedString: "Hello",
        segments: [],
        speakingRate: 1
      ),
      transcriptions: [],
      isFinal: false
    )
    var finalResult = result
    finalResult.bestTranscription.formattedString = "Hello world"
    finalResult.isFinal = true

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.send(.taskResult(result)) },
      .receive(.speech(.success(.taskResult(result)))) {
        $0.transcribedText = "Hello"
      },

      .do { self.recognitionTaskSubject.send(.taskResult(finalResult)) },
      .receive(.speech(.success(.taskResult(finalResult)))) {
        $0.transcribedText = "Hello world"
      }
    )
  }

  func testAudioSessionFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.eraseToEffect() },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.send(completion: .failure(.couldntConfigureAudioSession)) },
      .receive(.speech(.failure(.couldntConfigureAudioSession))) {
        $0.alert = .init(title: "Problem with audio device. Please try again.")
      },

      .do { self.recognitionTaskSubject.send(completion: .finished) }
    )
  }

  func testAudioEngineFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.eraseToEffect() },
          requestAuthorization: { Effect(value: .authorized) }
        )
      )
    )

    store.assert(
      .send(.recordButtonTapped) {
        $0.isRecording = true
      },

      .do { self.scheduler.advance() },
      .receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
        $0.speechRecognizerAuthorizationStatus = .authorized
      },

      .do { self.recognitionTaskSubject.send(completion: .failure(.couldntStartAudioEngine)) },
      .receive(.speech(.failure(.couldntStartAudioEngine))) {
        $0.alert = .init(title: "Problem with audio device. Please try again.")
      },

      .do { self.recognitionTaskSubject.send(completion: .finished) }
    )
  }
}
