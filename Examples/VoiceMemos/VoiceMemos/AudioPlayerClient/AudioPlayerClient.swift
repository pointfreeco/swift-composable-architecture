import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: (URL) -> Effect<Action, Error>
  var stop: () -> Effect<Never, Never>

  enum Action {
    case didFinishPlaying(successfully: Bool)
  }
}
