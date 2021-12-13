import AVFoundation
import ComposableArchitecture

extension AudioRecorderClient {
  static var live: Self {
    var delegate: AudioRecorderClientDelegate?

    return Self(
      currentTime: {
        .result {
          guard
            let recorder = delegate?.recorder,
            recorder.isRecording
          else { return .success(nil) }
          return .success(recorder.currentTime)
        }
      },
      requestRecordPermission: {
        .future { callback in
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            callback(.success(granted))
          }
        }
      },
      startRecording: { url in
        .future { callback in
          delegate?.recorder.stop()
          delegate = nil
          do {
            delegate = try AudioRecorderClientDelegate(
              url: url,
              didFinishRecording: { flag in
                callback(.success(.didFinishRecording(successfully: flag)))
                delegate = nil
                try? AVAudioSession.sharedInstance().setActive(false)
              },
              encodeErrorDidOccur: { _ in
                callback(.failure(.encodeErrorDidOccur))
                delegate = nil
                try? AVAudioSession.sharedInstance().setActive(false)
              }
            )
          } catch {
            callback(.failure(.couldntCreateAudioRecorder))
            return
          }

          do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
          } catch {
            callback(.failure(.couldntActivateAudioSession))
            return
          }

          do {
            try AVAudioSession.sharedInstance().setActive(true)
          } catch {
            callback(.failure(.couldntSetAudioSessionCategory))
            return
          }

          delegate?.recorder.record()
        }
      },
      stopRecording: {
        .fireAndForget {
          delegate?.recorder.stop()
          try? AVAudioSession.sharedInstance().setActive(false)
        }
      }
    )
  }
}

private class AudioRecorderClientDelegate: NSObject, AVAudioRecorderDelegate {
  let recorder: AVAudioRecorder
  let didFinishRecording: (Bool) -> Void
  let encodeErrorDidOccur: (Error?) -> Void

  init(
    url: URL,
    didFinishRecording: @escaping (Bool) -> Void,
    encodeErrorDidOccur: @escaping (Error?) -> Void
  ) throws {
    self.recorder = try AVAudioRecorder(
      url: url,
      settings: [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      ])
    self.didFinishRecording = didFinishRecording
    self.encodeErrorDidOccur = encodeErrorDidOccur
    super.init()
    self.recorder.delegate = self
  }

  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    self.didFinishRecording(flag)
  }

  func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    self.encodeErrorDidOccur(error)
  }
}
