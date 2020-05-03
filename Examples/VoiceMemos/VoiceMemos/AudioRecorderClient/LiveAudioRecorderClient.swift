import AVFoundation
import ComposableArchitecture

extension AudioRecorderClient {
  static let live = AudioRecorderClient(
    currentTime: { id in
      Effect.result {
        guard
          let recorder = dependencies[id]?.recorder,
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
    startRecording: { id, url in
      .future { callback in
        guard
          let delegate = try? AudioRecorderClientDelegate(
            url: url,
            didFinishRecording: { flag in
              callback(.success(.didFinishRecording(successfully: flag)))
              dependencies[id] = nil
            },
            encodeErrorDidOccur: { _ in
              callback(.failure(.encodeErrorDidOccur))
              dependencies[id] = nil
            }
          )
        else {
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
          try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
          callback(.failure(.couldntSetAudioSessionCategory))
          return
        }

        dependencies[id] = delegate
        delegate.recorder.record()
      }
    },
    stopRecording: { id in
      .fireAndForget {
        dependencies[id]?.recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
      }
    }
  )
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

private var dependencies: [AnyHashable: AudioRecorderClientDelegate] = [:]
