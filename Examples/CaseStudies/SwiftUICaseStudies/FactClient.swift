import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

struct FactClient {
  var fetch: @Sendable (Int) async throws -> String
}

extension DependencyValues {
  var factClient: FactClient {
    get { self[FactClient.self] }
    set { self[FactClient.self] = newValue }
  }
}

extension FactClient: DependencyKey {
  /// This is the "live" fact dependency that reaches into the outside world to fetch trivia.
  /// Typically this live implementation of the dependency would live in its own module so that the
  /// main feature doesn't need to compile it.
  static let liveValue = Self(
    fetch: { number in
      try await Task.sleep(for: .seconds(1))
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
      return String(decoding: data, as: UTF8.self)
    }
  )

  /// This is the "unimplemented" fact dependency that is useful to plug into tests that you want
  /// to prove do not need the dependency.
  static let testValue = Self(
    fetch: unimplemented("\(Self.self).fetch")
  )
}
