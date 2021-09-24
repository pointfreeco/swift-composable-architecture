import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioRecorderClient {
    static let failing = Self(
      currentTime: { _ in .failing("AudioRecorderClient.currentTime") },
      requestRecordPermission: { .failing("AudioRecorderClient.requestRecordPermission") },
      startRecording: { _, _ in .failing("AudioRecorderClient.startRecording") },
      stopRecording: { _ in .failing("AudioRecorderClient.stopRecording") }
    )
  }
#endif
