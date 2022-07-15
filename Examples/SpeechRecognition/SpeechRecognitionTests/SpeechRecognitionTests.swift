import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = PassthroughSubject<SpeechRecognitionResult, SpeechClient.Error>()

  func testDenyAuthorization() {
    var speechClient = SpeechClient.unimplemented
    speechClient.requestAuthorization = { Effect(value: .denied) }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
      $0.alert = AlertState(
        title: TextState(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .denied
    }
  }

  func testRestrictedAuthorization() {
    var speechClient = SpeechClient.unimplemented
    speechClient.requestAuthorization = { Effect(value: .restricted) }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = AlertState(title: TextState("Your device does not allow speech recognition."))
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .restricted
    }
  }

  func testAllowAndRecord() {
    var speechClient = SpeechClient.unimplemented
    speechClient.finishTask = {
      .fireAndForget { self.recognitionTaskSubject.send(completion: .finished) }
    }
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    let result = SpeechRecognitionResult(
      bestTranscription: Transcription(
        formattedString: "Hello",
        segments: []
      ),
      isFinal: false,
      transcriptions: []
    )
    var finalResult = result
    finalResult.bestTranscription.formattedString = "Hello world"
    finalResult.isFinal = true

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(result)
    store.receive(.speech(.success(result))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.send(finalResult)
    store.receive(.speech(.success(finalResult))) {
      $0.transcribedText = "Hello world"
    }
  }

  func testAudioSessionFailure() {
    var speechClient = SpeechClient.unimplemented
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(completion: .failure(.couldntConfigureAudioSession))
    store.receive(.speech(.failure(.couldntConfigureAudioSession))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }

  func testAudioEngineFailure() {
    var speechClient = SpeechClient.unimplemented
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { Effect(value: .authorized) }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(completion: .failure(.couldntStartAudioEngine))
    store.receive(.speech(.failure(.couldntStartAudioEngine))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }
}
