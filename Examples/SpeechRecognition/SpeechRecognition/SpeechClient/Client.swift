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
    static let testValue = SpeechClient.unimplemented
  }
}

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
