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
    get { self[SpeechClientKey.self] }
    set { self[SpeechClientKey.self] = newValue }
  }
}

enum SpeechClientKey: TestDependencyKey {
  static let previewValue = SpeechClient.lorem
  static let testValue = SpeechClient.unimplemented
}
