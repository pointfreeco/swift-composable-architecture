import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
  var finishTask: () -> Effect<Never, Never>
  var recognitionTask:
    (SFSpeechAudioBufferRecognitionRequest) -> Effect<SpeechRecognitionResult, Error>
  var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>

  enum Error: Swift.Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}
