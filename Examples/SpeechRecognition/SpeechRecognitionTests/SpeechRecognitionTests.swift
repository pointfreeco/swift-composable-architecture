import ComposableArchitecture
import XCTest

@testable import SpeechRecognition

@MainActor
final class SpeechRecognitionTests: XCTestCase {
  let recognitionTask = AsyncThrowingStream.makeStream(of: SpeechRecognitionResult.self)

  func testDenyAuthorization() async {
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.requestAuthorization = { .denied }
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(\.speechRecognizerAuthorizationStatusResponse) {
      $0.alert = AlertState {
        TextState(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
          """
        )
      }
      $0.isRecording = false
    }
  }

  func testRestrictedAuthorization() async {
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.requestAuthorization = { .restricted }
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }
    await store.receive(\.speechRecognizerAuthorizationStatusResponse) {
      $0.alert = AlertState { TextState("Your device does not allow speech recognition.") }
      $0.isRecording = false
    }
  }

  func testAllowAndRecord() async {
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.finishTask = { self.recognitionTask.continuation.finish() }
      $0.speechClient.startTask = { _ in self.recognitionTask.stream }
      $0.speechClient.requestAuthorization = { .authorized }
    }

    let firstResult = SpeechRecognitionResult(
      bestTranscription: Transcription(
        formattedString: "Hello",
        segments: []
      ),
      isFinal: false,
      transcriptions: []
    )
    var secondResult = firstResult
    secondResult.bestTranscription.formattedString = "Hello world"

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(\.speechRecognizerAuthorizationStatusResponse)

    self.recognitionTask.continuation.yield(firstResult)
    await store.receive(\.speech.success) {
      $0.transcribedText = "Hello"
    }

    self.recognitionTask.continuation.yield(secondResult)
    await store.receive(\.speech.success) {
      $0.transcribedText = "Hello world"
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = false
    }

    await store.finish()
  }

  func testAudioSessionFailure() async {
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.startTask = { _ in self.recognitionTask.stream }
      $0.speechClient.requestAuthorization = { .authorized }
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(\.speechRecognizerAuthorizationStatusResponse)

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntConfigureAudioSession)
    await store.receive(\.speech.failure) {
      $0.alert = AlertState { TextState("Problem with audio device. Please try again.") }
    }
  }

  func testAudioEngineFailure() async {
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.startTask = { _ in self.recognitionTask.stream }
      $0.speechClient.requestAuthorization = { .authorized }
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = true
    }

    await store.receive(\.speechRecognizerAuthorizationStatusResponse)

    recognitionTask.continuation.finish(throwing: SpeechClient.Failure.couldntStartAudioEngine)
    await store.receive(\.speech.failure) {
      $0.alert = AlertState { TextState("Problem with audio device. Please try again.") }
    }
  }
}
