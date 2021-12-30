import AVFoundation
import ComposableArchitecture

extension AudioPlayerClient {
  static var live: Self {
    var delegate: AudioPlayerClientDelegate?
    return Self(
      play: { url in
        .future { callback in
          delegate?.player.stop()
          delegate = nil
          do {
            delegate = try AudioPlayerClientDelegate(
              url: url,
              didFinishPlaying: { flag in
                callback(.success(.didFinishPlaying(successfully: flag)))
                delegate = nil
              },
              decodeErrorDidOccur: { _ in
                callback(.failure(.decodeErrorDidOccur))
                delegate = nil
              }
            )

            delegate?.player.play()
          } catch {
            callback(.failure(.couldntCreateAudioPlayer))
          }
        }
      },
      stop: {
        .fireAndForget {
          delegate?.player.stop()
          delegate = nil
        }
      }
    )
  }
}

private class AudioPlayerClientDelegate: NSObject, AVAudioPlayerDelegate {
  let didFinishPlaying: (Bool) -> Void
  let decodeErrorDidOccur: (Error?) -> Void
  let player: AVAudioPlayer

  init(
    url: URL,
    didFinishPlaying: @escaping (Bool) -> Void,
    decodeErrorDidOccur: @escaping (Error?) -> Void
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
