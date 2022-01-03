import Combine
import ComposableArchitecture
import XCTestDynamicOverlay

struct FactClient {
  var fetch: (Int) -> Effect<String, Error>

  struct Error: Swift.Error, Equatable {}
}

// This is the "live" fact dependency that reaches into the outside world to fetch trivia.
// Typically this live implementation of the dependency would live in its own module so that the
// main feature doesn't need to compile it.
extension FactClient {
  #if compiler(>=5.5)
    static let live = Self(
      fetch: { number in
        Effect.task {
          do {
            let (data, _) = try await URLSession.shared
              .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
            return String(decoding: data, as: UTF8.self)
          } catch {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            return "\(number) is a good number Brent"
          }
        }
        .setFailureType(to: Error.self)
        .eraseToEffect()
      }
    )
  #else
    static let live = Self(
      fetch: { number in
        URLSession.shared.dataTaskPublisher(
          for: URL(string: "http://numbersapi.com/\(number)/trivia")!
        )
        .map { data, _ in String(decoding: data, as: UTF8.self) }
        .catch { _ in
          // Sometimes numbersapi.com can be flakey, so if it ever fails we will just
          // default to a mock response.
          Just("\(number) is a good number Brent")
            .delay(for: 1, scheduler: DispatchQueue.main)
        }
        .setFailureType(to: Error.self)
        .eraseToEffect()
      }
    )
  #endif
}

#if DEBUG
  extension FactClient {
    // This is the "failing" fact dependency that is useful to plug into tests that you want
    // to prove do not need the dependency.
    static let failing = Self(
      fetch: { _ in
        XCTFail("\(Self.self).fact is unimplemented.")
        return .none
      }
    )
  }
#endif
