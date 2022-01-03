import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioRecorderClient {
    static let failing = Self(
      currentTime: { .failing("AudioRecorderClient.currentTime") },
      requestRecordPermission: { .failing("AudioRecorderClient.requestRecordPermission") },
      startRecording: { _ in .failing("AudioRecorderClient.startRecording") },
      stopRecording: { .failing("AudioRecorderClient.stopRecording") }
    )
  }
#endif
