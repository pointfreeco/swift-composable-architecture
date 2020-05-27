import Combine
import ComposableArchitecture
import Speech

extension SpeechClient {
  static let live = SpeechClient(
    cancelTask: { id in
      .fireAndForget {
        dependencies[id]?.cancel()
        dependencies[id] = nil
      }
    },
    finishTask: { id in
      .fireAndForget {
        dependencies[id]?.finish()
        dependencies[id]?.subscriber.send(completion: .finished)
        dependencies[id] = nil
      }
    },
    recognitionTask: { id, request in
      Effect.run { subscriber in
        let cancellable = AnyCancellable {
          dependencies[id]?.cancel()
          dependencies[id] = nil
        }

        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        let speechRecognizerDelegate = SpeechRecognizerDelegate(
          availabilityDidChange: { available in
            subscriber.send(.availabilityDidChange(isAvailable: available))
          }
        )
        speechRecognizer.delegate = speechRecognizerDelegate

        let audioEngine = AVAudioEngine()
        let audioSession = AVAudioSession.sharedInstance()
        do {
          try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
          try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
          subscriber.send(completion: .failure(.couldntConfigureAudioSession))
          return cancellable
        }
        let inputNode = audioEngine.inputNode

        let recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
          switch (result, error) {
          case let (.some(result), _):
            subscriber.send(.taskResult(SpeechRecognitionResult(result)))
          case let (_, .some(error)):
            subscriber.send(completion: .failure(.taskError))
          case (.none, .none):
            fatalError("It should not be possible to have both a nil result and nil error.")
          }
        }

        dependencies[id] = SpeechDependencies(
          audioEngine: audioEngine,
          inputNode: inputNode,
          recognitionTask: recognitionTask,
          speechRecognizer: speechRecognizer,
          speechRecognizerDelegate: speechRecognizerDelegate,
          subscriber: subscriber
        )

        inputNode.installTap(
          onBus: 0,
          bufferSize: 1024,
          format: inputNode.outputFormat(forBus: 0)
        ) { buffer, when in
          request.append(buffer)
        }

        audioEngine.prepare()
        do {
          try audioEngine.start()
        } catch {
          subscriber.send(completion: .failure(.couldntStartAudioEngine))
          return cancellable
        }

        return cancellable
      }
      .cancellable(id: id)
    },
    requestAuthorization: {
      .future { callback in
        SFSpeechRecognizer.requestAuthorization { status in
          callback(.success(status))
        }
      }
    }
  )
}

private struct SpeechDependencies {
  let audioEngine: AVAudioEngine
  let inputNode: AVAudioInputNode
  let recognitionTask: SFSpeechRecognitionTask
  let speechRecognizer: SFSpeechRecognizer
  let speechRecognizerDelegate: SpeechRecognizerDelegate
  let subscriber: Effect<SpeechClient.Action, SpeechClient.Error>.Subscriber

  func finish() {
    self.audioEngine.stop()
    self.inputNode.removeTap(onBus: 0)
    self.recognitionTask.finish()
  }

  func cancel() {
    self.audioEngine.stop()
    self.inputNode.removeTap(onBus: 0)
    self.recognitionTask.cancel()
  }
}

private var dependencies: [AnyHashable: SpeechDependencies] = [:]

private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
  var availabilityDidChange: (Bool) -> Void

  init(availabilityDidChange: @escaping (Bool) -> Void) {
    self.availabilityDidChange = availabilityDidChange
  }

  func speechRecognizer(
    _ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool
  ) {
    self.availabilityDidChange(available)
  }
}
