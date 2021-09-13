import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: (AnyHashable, URL) -> Effect<Action, Failure>
  var stop: (AnyHashable) -> Effect<Never, Never>

  enum Action: Equatable {
    case didFinishPlaying(successfully: Bool)
  }

  enum Failure: Equatable, Error {
    case couldntCreateAudioPlayer
    case decodeErrorDidOccur
  }
}

enum AudioPlayerClientKey: DependencyStub {
  static let testValue = AudioPlayerClient.failing
}
extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }
}
