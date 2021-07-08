import Combine
import ComposableArchitecture
import XCTestDynamicOverlay

struct FactClient {
  var fetch: (Int) -> Effect<String, Error>

  struct Error: Swift.Error, Equatable {}
}

extension FactClient {
  // This is the "live" fact dependency that reaches into the outside world to fetch trivia.
  // Typically this live implementation of the dependency would live in its own module so that the
  // main feature doesn't need to compile it.
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
    })
}

#if DEBUG
  extension FactClient {
    // This is the "failing" fact dependency that is useful to plug into tests that you want
    // to prove do not need the dependency.
    static let failing = Self(
      fetch: { _ in
        XCTFail("\(Self.self).fact is unimplemented.")
        return .none
      })
  }
#endif
