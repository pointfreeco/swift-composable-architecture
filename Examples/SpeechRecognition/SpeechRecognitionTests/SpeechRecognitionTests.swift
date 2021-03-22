import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

class SpeechRecognitionTests: XCTestCase {
  let recognitionTaskSubject = PassthroughSubject<SpeechClient.Action, SpeechClient.Error>()

  func testDenyAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: DispatchQueue.immediateScheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          requestAuthorization: { Effect(value: .denied) }
        )
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
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

  func testRestrictedAuthorization() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: DispatchQueue.immediateScheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          requestAuthorization: { Effect(value: .restricted) }
        )
      )
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = .init(title: .init("Your device does not allow speech recognition."))
      $0.isRecording = false
      $0.speechRecognizerAuthorizationStatus = .restricted
    }
  }

  func testAllowAndRecord() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: DispatchQueue.immediateScheduler.eraseToAnyScheduler(),
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

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    self.recognitionTaskSubject.send(.taskResult(result))
    store.receive(.speech(.success(.taskResult(result)))) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTaskSubject.send(.taskResult(finalResult))
    store.receive(.speech(.success(.taskResult(finalResult)))) {
      $0.transcribedText = "Hello world"
    }
  }

  func testAudioSessionFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: DispatchQueue.immediateScheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.eraseToEffect() },
          requestAuthorization: { Effect(value: .authorized) }
        )
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
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }

  func testAudioEngineFailure() {
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: DispatchQueue.immediateScheduler.eraseToAnyScheduler(),
        speechClient: .mock(
          recognitionTask: { _, _ in self.recognitionTaskSubject.eraseToEffect() },
          requestAuthorization: { Effect(value: .authorized) }
        )
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
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }

    self.recognitionTaskSubject.send(completion: .finished)
  }
}
