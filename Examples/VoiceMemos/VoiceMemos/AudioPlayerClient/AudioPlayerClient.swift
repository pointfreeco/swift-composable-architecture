import ComposableArchitecture
import Foundation

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }

  private enum AudioPlayerClientKey: LiveDependencyKey {
    static let liveValue = AudioPlayerClient.live
    static let testValue = AudioPlayerClient.failing
  }
}

struct AudioPlayerClient {
  var play: (URL) -> Effect<Action, Failure>
  var stop: () -> Effect<Never, Never>

  enum Action: Equatable {
    case didFinishPlaying(successfully: Bool)
  }

  enum Failure: Equatable, Error {
    case couldntCreateAudioPlayer
    case decodeErrorDidOccur
  }
}
