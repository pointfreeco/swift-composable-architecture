import Combine
import Dependencies
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

extension DependencyValues {
  var speechClient: SpeechClient {
    get { self[SpeechClient.self] }
    set { self[SpeechClient.self] = newValue }
  }
}

extension SpeechClient: TestDependencyKey {
  static let previewValue = SpeechClient.lorem
  static let testValue = SpeechClient.unimplemented
}
