import ComposableArchitecture
import Foundation

extension DependencyValues {
  var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClientKey.self] }
    set { self[AudioRecorderClientKey.self] = newValue }
  }

  private enum AudioRecorderClientKey: LiveDependencyKey {
    static let liveValue = AudioRecorderClient.live
    static let testValue = AudioRecorderClient.failing
  }
}

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
