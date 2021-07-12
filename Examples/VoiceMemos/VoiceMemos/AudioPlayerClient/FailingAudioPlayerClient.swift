import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioPlayerClient {
    static let failing = Self(
      play: { _, _ in .failing("AudioPlayerClient.play") },
      stop: { _ in .failing("AudioPlayerClient.stop") }
    )
  }
#endif
