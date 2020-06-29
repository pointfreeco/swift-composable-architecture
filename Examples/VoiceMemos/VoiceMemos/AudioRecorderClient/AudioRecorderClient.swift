import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: (AnyHashable) -> Effect<TimeInterval?, Never>
  var requestRecordPermission: () -> Effect<Bool, Never>
  var startRecording: (AnyHashable, URL) -> Effect<Action, Failure>
  var stopRecording: (AnyHashable) -> Effect<Never, Never>

  enum Action: Hashable {
    case didFinishRecording(successfully: Bool)
  }

  enum Failure: Error, Hashable {
    case couldntCreateAudioRecorder
    case couldntActivateAudioSession
    case couldntSetAudioSessionCategory
    case encodeErrorDidOccur
  }
}
