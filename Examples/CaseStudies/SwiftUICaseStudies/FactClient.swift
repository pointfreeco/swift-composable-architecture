import Combine
import ComposableArchitecture
import XCTestDynamicOverlay

#if compiler(>=5.5)
enum ApiError: Equatable, Error {
  case invalidResponse
  case httpStatus(Int)
  case urlSession(NSError)
}

extension URLSession {
  func dataResult(from url: URL) async -> Result<Data, ApiError> {
    do {
      let (data, response) = try await data(from: url)
      guard let response = response as? HTTPURLResponse else {
        return .failure(.invalidResponse)
      }
      guard response.statusCode < 300 else {
        return .failure(.httpStatus(response.statusCode))
      }
      return .success(data)
    } catch let error {
      return .failure(.urlSession(error as NSError))
    }
  }
}
#endif

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
        Effect.task { () -> Result<Data, ApiError> in
          let url = URL(string: "http://numbersapi.com/\(number)/trivia")!
          return await URLSession.shared.dataResult(from: url)
        }
        .map { String.init(decoding: $0, as: UTF8.self) }
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
      })
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
      })
  }
#endif
