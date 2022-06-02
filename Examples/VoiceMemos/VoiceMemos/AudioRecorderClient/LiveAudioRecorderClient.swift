@preconcurrency import Foundation
import AVFoundation
import ComposableArchitecture

extension AudioRecorderClient {
  static var live: Self {
    actor AudioRecorder {
      var delegate: AudioRecorderClientDelegate?
      init(delegate: AudioRecorderClientDelegate? = nil) {
        self.delegate = delegate
      }
      var currentTime: TimeInterval? {
        guard
          let delegate = self.delegate,
          delegate.recorder.isRecording
        else { return nil }
        return delegate.recorder.currentTime
      }
      func stop() {
        self.delegate?.recorder.stop()
      }
      func set(delegate: AudioRecorderClientDelegate?) {
        self.delegate = delegate
      }
      func record() {
        self.delegate?.recorder.record()
      }
    }

    var delegate: AudioRecorderClientDelegate?
    let audioRecorder = AudioRecorder()

    return Self(
      currentTime: { await audioRecorder.currentTime },
      requestRecordPermission: {
        await withUnsafeContinuation { continuation in
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            continuation.resume(returning: granted)
          }
        }
      },
      startRecording: { url in
        return .init { continuation in
          Task {
            // OK to put these in the task and not outside?
            await audioRecorder.stop()
            await audioRecorder.set(delegate: nil)

            do {
              try await audioRecorder.set(
                delegate: .init(
                  url: url,
                  didFinishRecording: { flag in
                    continuation.yield(.success(.didFinishRecording(successfully: flag)))
                    // audioRecorder.set(delegate: nil)
                    try? AVAudioSession.sharedInstance().setActive(false)
                  },
                  encodeErrorDidOccur: { error in
                    guard let error = error
                    else {
                      continuation.yield(.failure(AudioRecorderClient.Failure.encodeErrorDidOccur))
                      return
                    }
                    continuation.yield(.failure(error))
                    // audioRecorder.set(delegate: nil)
                    try? AVAudioSession.sharedInstance().setActive(false)
                  }
                )
              )
            } catch {
              continuation.yield(.failure(error))
              return
            }

            do {
              try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
              try AVAudioSession.sharedInstance().setActive(true)
            } catch {
              continuation.yield(.failure(error))
              return
            }

            continuation.onTermination = { _ in
              // TODO: what to do here?
            }

            await audioRecorder.record()
          }
        }
      },
      stopRecording: {
        await audioRecorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
      }
    )
  }
}

private final class AudioRecorderClientDelegate: NSObject, AVAudioRecorderDelegate, Sendable {
  @UncheckedSendable var recorder: AVAudioRecorder
  let didFinishRecording: @Sendable (Bool) -> Void
  let encodeErrorDidOccur: @Sendable (Error?) -> Void

  init(
    url: URL,
    didFinishRecording: @escaping @Sendable (Bool) -> Void,
    encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
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
