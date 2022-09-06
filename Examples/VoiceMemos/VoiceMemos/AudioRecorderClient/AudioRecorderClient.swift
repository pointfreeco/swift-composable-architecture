import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool
  var startRecording: @Sendable (URL) async throws -> Bool
  var stopRecording: @Sendable () async -> Void
}

private enum AudioRecorderClientKey: DependencyKey {
  static let liveValue = AudioRecorderClient.live
  static let testValue = AudioRecorderClient.unimplemented
}
extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClientKey.self] }
    set { self[AudioRecorderClientKey.self] = newValue }
  }
}
