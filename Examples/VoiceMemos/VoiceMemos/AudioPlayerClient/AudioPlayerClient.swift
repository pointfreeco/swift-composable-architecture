import Dependencies
import Foundation

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

private enum AudioPlayerClientKey: DependencyKey {
  static let testValue = AudioPlayerClient.unimplemented
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }
}

extension AudioPlayerClientKey: LiveDependencyKey {
  static let liveValue = AudioPlayerClient.live
}
