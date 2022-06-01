import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
  var recognitionTask:
    @Sendable (SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<Action, Error>
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus

  enum Action: Equatable {
    case availabilityDidChange(isAvailable: Bool)
    case taskResult(SpeechRecognitionResult)
  }

  enum Failure: Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
