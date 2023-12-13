import ComposableArchitecture
import Foundation

@DependencyClient
struct AudioPlayerClient {
  var play: @Sendable (_ url: URL) async throws -> Bool
}

extension AudioPlayerClient: TestDependencyKey {
  static let previewValue = Self(
    play: { _ in
      try await Task.sleep(for: .seconds(5))
      return true
    }
  )

  static let testValue = Self()
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}
