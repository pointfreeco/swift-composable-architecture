import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: (AnyHashable) -> Effect<TimeInterval?, Never>
  var requestRecordPermission: () -> Effect<Bool, Never>
  var startRecording: (AnyHashable, URL) -> Effect<Action, Failure>
  var stopRecording: (AnyHashable) -> Effect<Never, Never>

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
