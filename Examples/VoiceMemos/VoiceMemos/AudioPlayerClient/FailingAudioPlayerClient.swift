import ComposableArchitecture
import Foundation

#if DEBUG
  extension AudioPlayerClient {
    static let unimplemented = Self(
      play: { _ in .unimplemented("\(Self.self).play") },
      stop: { .unimplemented("\(Self.self).stop") }
    )
  }
#endif
