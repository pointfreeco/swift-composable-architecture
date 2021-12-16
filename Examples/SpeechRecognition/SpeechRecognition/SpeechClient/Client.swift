import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
  var finishTask: () -> Effect<Never, Never>
  var recognitionTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<Action, Error>
  var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>

  enum Action {
    case availabilityDidChange(isAvailable: Bool)
    case taskResult(SpeechRecognitionResult)
  }

  enum Error: Swift.Error {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
