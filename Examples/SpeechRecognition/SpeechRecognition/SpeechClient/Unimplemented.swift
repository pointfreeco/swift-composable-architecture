import Combine
import ComposableArchitecture
import Speech

#if DEBUG
  extension SpeechClient {
    static let unimplemented = Self(
      finishTask: { .unimplemented("\(Self.self).finishTask") },
      recognitionTask: { _ in .unimplemented("\(Self.self).recognitionTask") },
      requestAuthorization: { .unimplemented("\(Self.self).requestAuthorization") }
    )
  }
#endif
