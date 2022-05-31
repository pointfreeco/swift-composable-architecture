import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
  var finishTask: () async -> Void
  var recognitionTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<Action, Error>
  var requestAuthorization: () async -> SFSpeechRecognizerAuthorizationStatus

  enum Action: Equatable {
    case availabilityDidChange(isAvailable: Bool)
    case taskResult(SpeechRecognitionResult)
  }

  enum Error: Swift.Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
