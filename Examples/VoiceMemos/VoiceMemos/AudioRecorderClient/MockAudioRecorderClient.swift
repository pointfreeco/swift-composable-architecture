import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioRecorderClient {
    static func mock(
      currentTime: @escaping (AnyHashable) -> Effect<TimeInterval?, Never> = { _ in fatalError() },
      requestRecordPermission: @escaping () -> Effect<Bool, Never> = { fatalError() },
      startRecording: @escaping (AnyHashable, URL) -> Effect<Action, Failure> = { _, _ in
        fatalError()
      },
      stopRecording: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
    ) -> Self {
      Self(
        currentTime: currentTime,
        requestRecordPermission: requestRecordPermission,
        startRecording: startRecording,
        stopRecording: stopRecording
      )
    }
  }
#endif
