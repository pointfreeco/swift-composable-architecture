import Dependencies
import Foundation
import XCTestDynamicOverlay

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}

extension AudioPlayerClient: TestDependencyKey {
  static let previewValue = Self(
    play: { _ in
      try await Task.sleep(for: .seconds(5))
      return true
    }
  )

  static let testValue = Self(
    play: unimplemented("\(Self.self).play")
  )
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}
