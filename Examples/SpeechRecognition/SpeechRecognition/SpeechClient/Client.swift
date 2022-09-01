import Combine
import Speech

struct SpeechClient {
  var finishTask: @Sendable () async -> Void
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus
  var startTask:
    @Sendable (SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
      SpeechRecognitionResult, Error
    >

  enum Failure: Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
