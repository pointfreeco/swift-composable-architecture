import ComposableArchitecture
import Foundation

struct AudioRecorderClient {
  var currentTime: () -> Effect<TimeInterval?, Never>
  var requestRecordPermission: () -> Effect<Bool, Never>
  var startRecording: (URL) -> Effect<Action, Error>
  var stopRecording: () -> Effect<Never, Never>

  enum Action {
    case didFinishRecording(successfully: Bool)
  }
}
