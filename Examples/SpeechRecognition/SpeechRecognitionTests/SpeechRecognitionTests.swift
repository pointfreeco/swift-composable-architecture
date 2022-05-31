import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

@MainActor
class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = PassthroughSubject<SpeechClient.Action, SpeechClient.Error>()

  func testDenyAuthorization() async {
    var speechClient = SpeechClient.failing
    speechClient.requestAuthorization = { .denied }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
      $0.alert = .init(
        title: .init(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .denied
    }
  }

  func testRestrictedAuthorization() async {
    var speechClient = SpeechClient.failing
    speechClient.requestAuthorization = { .restricted }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = .init(title: .init("Your device does not allow speech recognition."))
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .restricted
    }
  }

  func testAllowAndRecord() async {
    var speechClient = SpeechClient.failing
    speechClient.finishTask = { self.recognitionTaskSubject.send(completion: .finished) }
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: .init(),
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

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(.taskResult(result))
    await store.receive(.speech(.success(.taskResult(result)))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.send(.taskResult(finalResult))
    await store.receive(.speech(.success(.taskResult(finalResult)))) {
      $0.transcribedText = "Hello world"
    }
  }

  func testAudioSessionFailure() async {
    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(completion: .failure(.couldntConfigureAudioSession))
    await store.receive(.speech(.failure(SpeechClient.Error.couldntConfigureAudioSession))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }

  func testAudioEngineFailure() async {
    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in self.recognitionTaskSubject.eraseToEffect() }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: .immediate,
        speechClient: speechClient
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(completion: .failure(.couldntStartAudioEngine))
    await store.receive(.speech(.failure(SpeechClient.Error.couldntStartAudioEngine))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }
}
