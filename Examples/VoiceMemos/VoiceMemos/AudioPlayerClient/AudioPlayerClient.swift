import Dependencies
import Foundation

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

private enum AudioPlayerClientKey: TestDependencyKey {
  static let testValue = AudioPlayerClient.unimplemented
}
extension AudioPlayerClientKey: DependencyKey {
  static let liveValue = AudioPlayerClient.live
}
extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }
}
