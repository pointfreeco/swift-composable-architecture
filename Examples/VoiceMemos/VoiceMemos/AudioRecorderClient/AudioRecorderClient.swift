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
    let isRecording = ActorIsolated(false)
    let currentTime = ActorIsolated(0.0)

    return Self(
      currentTime: { await currentTime.value },
      requestRecordPermission: { true },
      startRecording: { _ in
        await isRecording.setValue(true)
        while await isRecording.value {
          try await Task.sleep(for: .seconds(1))
          await currentTime.withValue { $0 += 1 }
        }
        return true
      },
      stopRecording: {
        await isRecording.setValue(false)
        await currentTime.setValue(0)
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
