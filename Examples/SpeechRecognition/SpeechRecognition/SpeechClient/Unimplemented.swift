import Combine
import ComposableArchitecture
import Speech

#if DEBUG
  extension SpeechClient {
    static let unimplemented = Self(
      finishTask: { .unimplemented("\(Self.self).finishTask") },
      requestAuthorization: { .unimplemented("\(Self.self).requestAuthorization") },
      startTask: { _ in .unimplemented("\(Self.self).recognitionTask") }
    )
  }
#endif
