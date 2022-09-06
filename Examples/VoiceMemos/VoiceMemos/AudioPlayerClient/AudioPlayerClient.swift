import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

private enum AudioPlayerClientKey: DependencyKey {
  static let defaultValue = AudioPlayerClient.live
}
extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }
}
