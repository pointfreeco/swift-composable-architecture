import ComposableArchitecture
import Testing

@testable import SpeechRecognition

@MainActor
struct SpeechRecognitionTests {
  @Test
  func denyAuthorization() async {
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

  @Test
  func restrictedAuthorization() async {
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

  @Test
  func allowAndRecord() async {
    let recognitionTask = AsyncThrowingStream.makeStream(of: SpeechRecognitionResult.self)
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.finishTask = { recognitionTask.continuation.finish() }
      $0.speechClient.startTask = { @Sendable _ in recognitionTask.stream }
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

    recognitionTask.continuation.yield(firstResult)
    await store.receive(\.speech.success) {
      $0.transcribedText = "Hello"
    }

    recognitionTask.continuation.yield(secondResult)
    await store.receive(\.speech.success) {
      $0.transcribedText = "Hello world"
    }

    await store.send(.recordButtonTapped) {
      $0.isRecording = false
    }

    await store.finish()
  }

  @Test
  func audioSessionFailure() async {
    let recognitionTask = AsyncThrowingStream.makeStream(of: SpeechRecognitionResult.self)
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.startTask = { @Sendable _ in recognitionTask.stream }
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

  @Test
  func audioEngineFailure() async {
    let recognitionTask = AsyncThrowingStream.makeStream(of: SpeechRecognitionResult.self)
    let store = TestStore(initialState: SpeechRecognition.State()) {
      SpeechRecognition()
    } withDependencies: {
      $0.speechClient.startTask = { @Sendable _ in recognitionTask.stream }
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
