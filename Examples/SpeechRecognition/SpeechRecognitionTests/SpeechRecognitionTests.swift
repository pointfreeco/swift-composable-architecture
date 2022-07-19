import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

@MainActor
class SpeechRecognitionTests: XCTestCase {
  func testDenyAuthorization() async {
    var speechClient = SpeechClient.unimplemented
    speechClient.requestAuthorization = { .denied }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        speechClient: speechClient
      )
    )

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
      $0.alert = AlertState(
        title: TextState(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      )
      $0.isRecording = false
    }
  }

  func testRestrictedAuthorization() async {
    var speechClient = SpeechClient.unimplemented
    speechClient.requestAuthorization = { .restricted }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        speechClient: speechClient
      )
    )

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
      $0.alert = AlertState(title: TextState("Your device does not allow speech recognition."))
      $0.isRecording = false
    }
  }

  func testAllowAndRecord() async {
    let recognitionTask = AsyncThrowingStream<SpeechRecognitionResult, Error>.streamWithContinuation()

    var speechClient = SpeechClient.unimplemented
    speechClient.startTask = { _ in recognitionTask.stream }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
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

    let task = await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    recognitionTask.continuation.yield(result)
    await store.receive(.speech(.success(result))) {
      $0.transcribedText = "Hello"
    }

    recognitionTask.continuation.yield(finalResult)
    await store.receive(.speech(.success(finalResult))) {
      $0.transcribedText = "Hello world"
    }
    await task.cancel()
  }

  func testAudioSessionFailure() async {
    let recognitionTask = AsyncThrowingStream<SpeechRecognitionResult, Error>.streamWithContinuation()

    var speechClient = SpeechClient.unimplemented
    speechClient.startTask = { _ in recognitionTask.stream }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        speechClient: speechClient
      )
    )

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntConfigureAudioSession)
    await store.receive(.speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }
  }

  func testAudioEngineFailure() async {
    let recognitionTask = AsyncThrowingStream<SpeechRecognitionResult, Error>.streamWithContinuation()

    var speechClient = SpeechClient.unimplemented
    speechClient.startTask = { _ in recognitionTask.stream }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        speechClient: speechClient
      )
    )

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntStartAudioEngine)
    await store.receive(.speech(.failure(SpeechClient.Failure.couldntStartAudioEngine))) {
      $0.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    }
  }
}
