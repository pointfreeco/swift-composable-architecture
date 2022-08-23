import Dependencies
import Foundation

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

enum AudioPlayerClientKey: TestDependencyKey {
  static var previewValue = AudioPlayerClient.mock
  static let testValue = AudioPlayerClient.unimplemented
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClientKey.self] }
    set { self[AudioPlayerClientKey.self] = newValue }
  }
}
