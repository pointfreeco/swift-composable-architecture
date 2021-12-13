import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: () -> Effect<TimeInterval?, Never>
  var requestRecordPermission: () -> Effect<Bool, Never>
  var startRecording: (URL) -> Effect<Action, Failure>
  var stopRecording: () -> Effect<Never, Never>

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
