import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: @Sendable () async -> TimeInterval?
  var requestRecordPermission: @Sendable () async -> Bool
  var startRecording: @Sendable (URL) -> AsyncStream<TaskResult<Action>>
  var stopRecording: @Sendable () async -> Void

  enum Action: Equatable {
    case didFinishRecording(successfully: Bool)
  }

  enum Failure: Equatable, Error {
    case couldntCreateAudioRecorder
    case couldntActivateAudioSession
    case couldntSetAudioSessionCategory
    case encodeErrorDidOccur
  }
}
