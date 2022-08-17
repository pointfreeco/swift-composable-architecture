import ComposableArchitecture
import Foundation

struct AudioPlayerClient {
  var play: @Sendable (URL) async throws -> Bool
}
