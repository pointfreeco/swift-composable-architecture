import Foundation

extension AudioPlayerClient {
  static let mock = Self(
    play: { _ in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
      return true
    }
  )
}
