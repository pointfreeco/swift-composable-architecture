import Combine
import ComposableArchitecture
import XCTestDynamicOverlay

struct FactClient {
  var fetch: (Int) -> Effect<String, Failure>
  var fetchAsync: @Sendable (Int) async throws /* Any */ -> String

  struct Failure: Error, Equatable {}
}

// This is the "live" fact dependency that reaches into the outside world to fetch trivia.
// Typically this live implementation of the dependency would live in its own module so that the
// main feature doesn't need to compile it.
extension FactClient {
  static let live = Self(
    fetch: { number in
      Effect.task {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        let (data, _) = try await URLSession.shared
          .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
        return String(decoding: data, as: UTF8.self)
      }
      .mapError { _ in Failure() }
      .eraseToEffect()
    },
    fetchAsync: { number in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
      return String(decoding: data, as: UTF8.self)
    }
  )
}

#if DEBUG
  extension FactClient {
    // This is the "unimplemented" fact dependency that is useful to plug into tests that you want
    // to prove do not need the dependency.
    static let unimplemented = Self(
      fetch: { _ in .unimplemented("\(Self.self).fetch") },
      fetchAsync: XCTUnimplemented("\(Self.self).fetchAsync")
    )
  }
#endif
