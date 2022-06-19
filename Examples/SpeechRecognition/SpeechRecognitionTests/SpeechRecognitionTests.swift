import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

@MainActor
class SpeechRecognitionTests: XCTestCase {
  func testDenyAuthorization() async {
    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.speechClient.requestAuthorization) { .denied }
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
    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.speechClient.requestAuthorization) { .restricted }
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
    let recognitionTask = AsyncThrowingStream<SpeechClient.Action, Error>.streamWithContinuation()

    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in recognitionTask.stream }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.speechClient.recognitionTask) { _ in recognitionTask.stream }
        .dependency(\.speechClient.requestAuthorization) { .authorized }
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

    let task = store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    recognitionTask.continuation.yield(.taskResult(result))
    await store.receive(.speech(.success(.taskResult(result)))) {
      $0.transcribedText = "Hello"
    }

    recognitionTask.continuation.yield(.taskResult(finalResult))
    await store.receive(.speech(.success(.taskResult(finalResult)))) {
      $0.transcribedText = "Hello world"
    }
    await task.cancel()
  }

  func testAudioSessionFailure() async {
    let recognitionTask = AsyncThrowingStream<SpeechClient.Action, Error>.streamWithContinuation()

    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.speechClient.recognitionTask) { _ in recognitionTask.stream }
        .dependency(\.speechClient.requestAuthorization) { .authorized }
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntConfigureAudioSession)
    await store.receive(.speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }
  }

  func testAudioEngineFailure() async {
    let recognitionTask = AsyncThrowingStream<SpeechClient.Action, Error>.streamWithContinuation()

    var speechClient = SpeechClient.failing
    speechClient.recognitionTask = { _ in recognitionTask.stream }
    speechClient.requestAuthorization = { .authorized }

    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.speechClient.recognitionTask) { _ in recognitionTask.stream }
        .dependency(\.speechClient.requestAuthorization) { .authorized }
    )

    store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized)) {
      $0.speechRecognizerAuthorizationStatus = .authorized
    }

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntStartAudioEngine)
    await store.receive(.speech(.failure(SpeechClient.Failure.couldntStartAudioEngine))) {
      $0.alert = .init(title: .init("Problem with audio device. Please try again."))
    }
  }
}
