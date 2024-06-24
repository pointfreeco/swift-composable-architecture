import ComposableArchitecture
import Foundation

@DependencyClient
struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool = { false }
  var startRecording: @Sendable (_ url: URL) async throws -> Bool
  var stopRecording: @Sendable () async -> Void
}

extension AudioRecorderClient: TestDependencyKey {
  static var previewValue: Self {
    let isRecording = LockIsolated(false)
    let currentTime = LockIsolated(0.0)

    return Self(
      currentTime: { currentTime.value },
      requestRecordPermission: { true },
      startRecording: { _ in
        isRecording.setValue(true)
        while isRecording.value {
          try await Task.sleep(for: .seconds(1))
          currentTime.withValue { $0 += 1 }
        }
        return true
      },
      stopRecording: {
        isRecording.setValue(false)
        currentTime.setValue(0)
      }
    )
  }

  static let testValue = Self()
}

extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}
