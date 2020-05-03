import AVFoundation
import ComposableArchitecture

extension AudioPlayerClient {
  static let live = AudioPlayerClient(
    play: { id, url in
      .future { callback in
        do {
          let delegate = try AudioPlayerClientDelegate(
            url: url,
            didFinishPlaying: { flag in
              callback(.success(.didFinishPlaying(successfully: flag)))
              dependencies[id] = nil
            },
            decodeErrorDidOccur: { _ in
              callback(.failure(.decodeErrorDidOccur))
              dependencies[id] = nil
            }
          )

          delegate.player.play()
          dependencies[id] = delegate
        } catch {
          callback(.failure(.couldntCreateAudioPlayer))
        }
      }
    },
    stop: { id in
      .fireAndForget {
        dependencies[id]?.player.stop()
        dependencies[id] = nil
      }
    }
  )
}

private var dependencies: [AnyHashable: AudioPlayerClientDelegate] = [:]

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
