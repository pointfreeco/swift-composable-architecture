import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: (AnyHashable, URL) -> Effect<Action, Failure>
  var stop: (AnyHashable) -> Effect<Never, Never>

  enum Action: Hashable {
    case didFinishPlaying(successfully: Bool)
  }

  enum Failure: Error, Hashable {
    case couldntCreateAudioPlayer
    case decodeErrorDidOccur
  }
}
