import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioRecorderClient {
    static let unimplemented = Self(
      currentTime: { .unimplemented("\(Self.self).currentTime") },
      requestRecordPermission: { .unimplemented("\(Self.self).requestRecordPermission") },
      startRecording: { _ in .unimplemented("\(Self.self).startRecording") },
      stopRecording: { .unimplemented("\(Self.self).stopRecording") }
    )
  }
#endif
