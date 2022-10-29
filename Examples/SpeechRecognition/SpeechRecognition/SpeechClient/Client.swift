import ComposableArchitecture
import Dependencies
import Speech
import XCTestDynamicOverlay

struct SpeechClient {
  var finishTask: @Sendable () async -> Void
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus
  var startTask:
    @Sendable (SFSpeechAudioBufferRecognitionRequest) async -> AsyncThrowingStream<
      SpeechRecognitionResult, Error
    >

  enum Failure: Error, Equatable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
  }
}

extension SpeechClient: TestDependencyKey {
  static var previewValue: Self {
    let isRecording = ActorIsolated(false)

    return Self(
      finishTask: { await isRecording.setValue(false) },
      requestAuthorization: { .authorized },
      startTask: { _ in
        AsyncThrowingStream { continuation in
          Task {
            await isRecording.setValue(true)
            var finalText = """
              Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
              incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
              exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute \
              irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla \
              pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui \
              officia deserunt mollit anim id est laborum.
              """
            var text = ""
            while await isRecording.value {
              let word = finalText.prefix { $0 != " " }
              try await Task.sleep(
                nanoseconds: UInt64(word.count) * NSEC_PER_MSEC * 50
                  + .random(in: 0...(NSEC_PER_MSEC * 200))
              )
              finalText.removeFirst(word.count)
              if finalText.first == " " {
                finalText.removeFirst()
              }
              text += word + " "
              continuation.yield(
                SpeechRecognitionResult(
                  bestTranscription: Transcription(
                    formattedString: text,
                    segments: []
                  ),
                  isFinal: false,
                  transcriptions: []
                )
              )
            }
          }
        }
      }
    )
  }

  static let testValue = Self(
    finishTask: unimplemented("\(Self.self).finishTask"),
    requestAuthorization: unimplemented(
      "\(Self.self).requestAuthorization", placeholder: .notDetermined
    ),
    startTask: unimplemented("\(Self.self).recognitionTask", placeholder: .never)
  )
}

extension DependencyValues {
  var speechClient: SpeechClient {
    get { self[SpeechClient.self] }
    set { self[SpeechClient.self] = newValue }
  }
}
