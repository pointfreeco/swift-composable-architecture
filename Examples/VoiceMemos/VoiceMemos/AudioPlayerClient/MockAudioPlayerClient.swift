import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioPlayerClient {
    static func mock(
      play: @escaping (AnyHashable, URL) -> Effect<Action, Failure> = { _, _ in fatalError() },
      stop: @escaping (AnyHashable) -> Effect<Never, Never> = { _ in fatalError() }
    ) -> Self {
      Self(
        play: play,
        stop: stop
      )
    }
  }
#endif
