import Dependencies
import Foundation

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool
  var startRecording: @Sendable (URL) async throws -> Bool
  var stopRecording: @Sendable () async -> Void
}

enum AudioRecorderClientKey: TestDependencyKey {
  static var previewValue = AudioRecorderClient.mock
  static let testValue = AudioRecorderClient.unimplemented
}

extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClientKey.self] }
    set { self[AudioRecorderClientKey.self] = newValue }
  }
}
