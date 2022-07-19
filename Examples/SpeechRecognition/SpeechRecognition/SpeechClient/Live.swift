import Combine
import ComposableArchitecture
@preconcurrency import Speech

extension SpeechClient {
  static var live: Self {
    let speech = Speech()

    return Self(
      finishTask: { await speech.finishTask() },
      requestAuthorization: {
        await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
          }
        }
      },
      startTask: { request in await speech.startTask(request: request) }
    )
  }
}

private actor Speech {
  var audioEngine: AVAudioEngine? = nil
  var recognitionTask: SFSpeechRecognitionTask? = nil

  func finishTask() {
    self.audioEngine?.stop()
    self.audioEngine?.inputNode.removeTap(onBus: 0)
    self.recognitionTask?.finish()
  }

  func startTask(
    request: SFSpeechAudioBufferRecognitionRequest
  ) -> AsyncThrowingStream<SpeechRecognitionResult, Error> {
    AsyncThrowingStream { continuation in

      let audioSession = AVAudioSession.sharedInstance()
      do {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      } catch {
        continuation.finish(throwing: SpeechClient.Failure.couldntConfigureAudioSession)
        return
      }

      self.audioEngine = AVAudioEngine()
      let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
      self.recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
        switch (result, error) {
        case let (.some(result), _):
          continuation.yield(SpeechRecognitionResult(result))
        case (_, .some):
          continuation.finish(throwing: SpeechClient.Failure.taskError)
        case (.none, .none):
          fatalError("It should not be possible to have both a nil result and nil error.")
        }
      }

      continuation.onTermination = {
        [speechRecognizer = UncheckedSendable(speechRecognizer),
         audioEngine = UncheckedSendable(audioEngine),
         recognitionTask = UncheckedSendable(recognitionTask)]
        _ in

        _ = speechRecognizer
        audioEngine.wrappedValue?.stop()
        audioEngine.wrappedValue?.inputNode.removeTap(onBus: 0)
        recognitionTask.wrappedValue?.finish()
      }

      self.audioEngine?.inputNode.installTap(
        onBus: 0,
        bufferSize: 1024,
        format: self.audioEngine?.inputNode.outputFormat(forBus: 0)
      ) { buffer, when in
        request.append(buffer)
      }

      self.audioEngine?.prepare()
      do {
        try self.audioEngine?.start()
      } catch {
        continuation.finish(throwing: SpeechClient.Failure.couldntStartAudioEngine)
        return
      }
    }
  }
}
