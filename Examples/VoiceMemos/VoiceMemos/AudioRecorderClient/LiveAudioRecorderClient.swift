@preconcurrency import Foundation
import AVFoundation
import ComposableArchitecture

extension AudioRecorderClient {
  static var live: Self {
    actor AudioRecorder {
      var delegate: Delegate?
      var recorder: AVAudioRecorder?

      init() {
      }

      var currentTime: TimeInterval? {
        guard
          let recorder = self.recorder,
          recorder.isRecording
        else { return nil }
        return recorder.currentTime
      }

      func stop() {
        self.recorder?.stop()
      }

      func start(url: URL) async throws -> Bool {
        self.recorder?.stop()

        let stream = AsyncThrowingStream<Bool, Error> { continuation in
          do {
            self.delegate = Delegate(
              didFinishRecording: { flag in
                continuation.yield(flag)
                continuation.finish()
                try? AVAudioSession.sharedInstance().setActive(false)
              },
              encodeErrorDidOccur: { error in
                guard let error = error
                else {
                  continuation.finish(throwing: AudioRecorderClient.Failure.encodeErrorDidOccur)
                  return
                }
                continuation.finish(throwing: error)
                try? AVAudioSession.sharedInstance().setActive(false)
              }
            )
            let recorder = try AVAudioRecorder(
              url: url,
              settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
              ])
            self.recorder = recorder
            recorder.delegate = self.delegate

            continuation.onTermination = { [recorder = UncheckedSendable(wrappedValue: recorder)] _ in
              recorder.wrappedValue.stop()
            }

            do {
              try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
              try AVAudioSession.sharedInstance().setActive(true)
            } catch {
              continuation.finish(throwing: error)
              return
            }

            self.recorder?.record()
          } catch {
            continuation.finish(throwing: error)
          }
        }

        guard let action = try await stream.first(where: { _ in true })
        else { throw CancellationError() }
        return action
      }
    }

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
        try await audioRecorder.start(url: url)
      },
      stopRecording: {
        await audioRecorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
      }
    )
  }
}

private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
  let didFinishRecording: @Sendable (Bool) -> Void
  let encodeErrorDidOccur: @Sendable (Error?) -> Void

  init(
    didFinishRecording: @escaping @Sendable (Bool) -> Void,
    encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) {
    self.didFinishRecording = didFinishRecording
    self.encodeErrorDidOccur = encodeErrorDidOccur
  }

  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    self.didFinishRecording(flag)
  }

  func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    self.encodeErrorDidOccur(error)
  }
}
