import Combine
import Speech

struct SpeechClient {
  var recognitionTask:
    @Sendable (SFSpeechAudioBufferRecognitionRequest) -> AsyncThrowingStream<SpeechRecognitionResult, Error>
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus

  enum Failure: Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
