import Combine
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

struct FactClient {
  var fetch: @Sendable (Int) async throws -> String
}

extension DependencyValues {
  var factClient: FactClient {
    get { self[FactClientKey.self] }
    set { self[FactClientKey.self] = newValue }
  }

  private enum FactClientKey: DependencyKey {
    static let liveValue = FactClient.live
    static let testValue = FactClient.unimplemented
  }
}

extension FactClient {
  /// This is the "live" fact dependency that reaches into the outside world to fetch trivia.
  /// Typically this live implementation of the dependency would live in its own module so that the
  /// main feature doesn't need to compile it.
  static let live = Self(
    fetch: { number in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
      return String(decoding: data, as: UTF8.self)
    }
  )
}

extension FactClient {
  /// This is the "unimplemented" fact dependency that is useful to plug into tests that you want
  /// to prove do not need the dependency.
  static let unimplemented = Self(
    fetch: XCTUnimplemented("\(Self.self).fetch")
  )
}
