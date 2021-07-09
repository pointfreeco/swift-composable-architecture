import Combine
import ComposableArchitecture
import Speech

#if DEBUG
  extension SpeechClient {
    static func mock(
      finishTask: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in
        fatalError("finishTask is not implemented in this mock.")
      },
      recognitionTask: @escaping (AnyHashable, SFSpeechAudioBufferRecognitionRequest) -> Effect<
        Action, Error
      > = { _, _ in fatalError("recognitionTask is not implemented in this mock.") },
      requestAuthorization: @escaping () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never> = {
        fatalError("requestAuthorization is not implemented in this mock.")
      }
    ) -> Self {
      Self(
        finishTask: finishTask,
        recognitionTask: recognitionTask,
        requestAuthorization: requestAuthorization
      )
    }
  }
#endif
