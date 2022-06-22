@preconcurrency import AVFoundation
import ComposableArchitecture

extension AudioPlayerClient {
  final class Delegate: NSObject, AVAudioPlayerDelegate, Sendable {
    let didFinishPlaying: @Sendable (Bool) -> Void
    let decodeErrorDidOccur: @Sendable (Error?) -> Void
    let player: AVAudioPlayer

    init(
      url: URL,
      didFinishPlaying: @escaping @Sendable (Bool) -> Void,
      decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
    ) throws {
      self.didFinishPlaying = didFinishPlaying
      self.decodeErrorDidOccur = decodeErrorDidOccur
      self.player = try AVAudioPlayer(contentsOf: url)
      super.init()
      self.player.delegate = self
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
      self.didFinishPlaying(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
      self.decodeErrorDidOccur(error)
    }
  }

  static let live = Self { url in
    let stream = AsyncThrowingStream<Bool, Error> { continuation in
      guard
        let delegate = try? Delegate(
          url: url,
          didFinishPlaying: { successful in
            continuation.yield(successful)
            continuation.finish()
          },
          decodeErrorDidOccur: { _ in
            continuation.finish(throwing: Failure.decodeErrorDidOccur)
          }
        )
      else {
        continuation.finish(throwing: Failure.couldntCreateAudioPlayer)
        return
      }

      delegate.player.play()

      continuation.onTermination = { _ in
        delegate.player.stop()
      }
    }
    for try await successful in stream {
      return successful
    }
    struct EarlyCompletion: Error {}
    throw EarlyCompletion()
  }
}
