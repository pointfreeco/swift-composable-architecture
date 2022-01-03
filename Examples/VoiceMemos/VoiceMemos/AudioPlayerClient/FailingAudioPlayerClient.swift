import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioPlayerClient {
    static let failing = Self(
      play: { _ in .failing("AudioPlayerClient.play") },
      stop: { .failing("AudioPlayerClient.stop") }
    )
  }
#endif
