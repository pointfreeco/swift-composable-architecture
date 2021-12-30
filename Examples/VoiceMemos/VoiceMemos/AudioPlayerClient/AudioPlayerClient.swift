import ComposableArchitecture
import Foundation

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
