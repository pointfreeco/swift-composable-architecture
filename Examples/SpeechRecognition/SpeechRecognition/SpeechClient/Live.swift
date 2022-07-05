import Combine
import ComposableArchitecture
@preconcurrency import Speech

extension SpeechClient {
  static let live = Self(
    recognitionTask: { request in
      AsyncThrowingStream { continuation in
        let audioEngine = AVAudioEngine()
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!

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
            continuation.yield(SpeechRecognitionResult(result))
          case (_, .some):
            continuation.finish(throwing: Failure.taskError)
          case (.none, .none):
            fatalError("It should not be possible to have both a nil result and nil error.")
          }
        }

        continuation.onTermination = { _ in
          _ = speechRecognizer
          audioEngine.stop()
          audioEngine.inputNode.removeTap(onBus: 0)
          recognitionTask.finish()
        }

        audioEngine.inputNode.installTap(
          onBus: 0,
          bufferSize: 1024,
          format: audioEngine.inputNode.outputFormat(forBus: 0)
        ) { buffer, when in
          request.append(buffer)
        }

        audioEngine.prepare()
        do {
          try audioEngine.start()
        } catch {
          continuation.finish(throwing: Failure.couldntStartAudioEngine)
          return
        }
      }
    },
    requestAuthorization: {
      await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status)
        }
      }
    }
  )
}
