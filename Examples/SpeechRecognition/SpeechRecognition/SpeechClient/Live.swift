import Combine
import ComposableArchitecture
@preconcurrency import Speech

extension SpeechClient {
  static var live: Self {
    final class Delegate: NSObject, Sendable, SFSpeechRecognizerDelegate {
      let availabilityDidChange: @Sendable (Bool) -> Void

      init(availabilityDidChange: @escaping @Sendable (Bool) -> Void) {
        self.availabilityDidChange = availabilityDidChange
      }

      func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool
      ) {
        self.availabilityDidChange(available)
      }
    }

    final actor Actor {
      let audioEngine = AVAudioEngine()
      var recognitionTask: SFSpeechRecognitionTask?

      func recognitionTask(
        request: SFSpeechAudioBufferRecognitionRequest
      ) -> AsyncThrowingStream<Action, Error> {
        .init { continuation in
          let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
          let speechRecognizerDelegate = Delegate { available in
            continuation.yield(.availabilityDidChange(isAvailable: available))
          }
          speechRecognizer.delegate = speechRecognizerDelegate

          continuation.onTermination = { _ in
            _ = speechRecognizer
            _ = speechRecognizerDelegate
            Task {
              self.audioEngine.stop()
              self.audioEngine.inputNode.removeTap(onBus: 0)
              await self.recognitionTask?.finish()
            }
          }

          let audioSession = AVAudioSession.sharedInstance()
          do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
          } catch {
            continuation.finish(throwing: Failure.couldntConfigureAudioSession)
            return
          }

          let recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            switch (result, error) {
            case let (.some(result), _):
              continuation.yield(.taskResult(SpeechRecognitionResult(result)))
            case (_, .some):
              continuation.finish(throwing: Failure.taskError)
            case (.none, .none):
              fatalError("It should not be possible to have both a nil result and nil error.")
            }
          }
          self.recognitionTask = recognitionTask

          self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: self.audioEngine.inputNode.outputFormat(forBus: 0)
          ) { buffer, when in
            request.append(buffer)
          }

          self.audioEngine.prepare()
          do {
            try self.audioEngine.start()
          } catch {
            continuation.finish(throwing: Failure.couldntStartAudioEngine)
            return
          }
        }
      }
    }

    let actor = Actor()

    return Self(
      recognitionTask: { await actor.recognitionTask(request: $0) },
      requestAuthorization: {
        await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
          }
        }
      }
    )
  }
}
