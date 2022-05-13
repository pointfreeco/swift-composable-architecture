import Combine
import ComposableArchitecture
import Speech

extension DependencyValues {
  var speechClient: SpeechClient {
    get { self[SpeechClientKey.self] }
    set { self[SpeechClientKey.self] = newValue }
  }

  private enum SpeechClientKey: LiveDependencyKey {
    static let liveValue = SpeechClient.live
    static let testValue = SpeechClient.failing
  }
}

struct SpeechClient {
  var finishTask: () -> Effect<Never, Never>
  var recognitionTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<Action, Error>
  var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>

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
