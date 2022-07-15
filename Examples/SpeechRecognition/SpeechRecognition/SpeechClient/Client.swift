import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
  var finishTask: () -> Effect<Never, Never>
  var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>
  var startTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<SpeechRecognitionResult, Error>

  enum Error: Swift.Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
