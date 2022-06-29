import Combine
import ComposableArchitecture
import Speech
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a complex dependency in the Composable \
  Architecture. It uses the SFSpeechRecognizer API from the Speech framework to listen to audio on \
  the device and live-transcribe it to the UI.
  """

struct AppReducer: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var isRecording = false
    var speechRecognizerAuthorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
    var transcribedText = ""
  }

  enum Action: Equatable {
    case dismissAuthorizationStateAlert
    case recordButtonTapped
    case speech(TaskResult<SpeechClient.Action>)
    case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
  }

  @Dependency(\.speechClient) var speechClient

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum CancelId {}

    switch action {
    case .dismissAuthorizationStateAlert:
      state.alert = nil
      return .none

    case .recordButtonTapped:
      state.isRecording.toggle()
      if state.isRecording {
        return .task {
          .speechRecognizerAuthorizationStatusResponse(
            await self.speechClient.requestAuthorization()
          )
        }
        .cancellable(id: CancelId.self)
      } else {
        return .cancel(id: CancelId.self)
      }

    case .speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession)),
      .speech(.failure(SpeechClient.Failure.couldntStartAudioEngine)):
      state.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
      return .none

    case .speech(.failure):
      state.alert = AlertState(
        title: TextState("An error occurred while transcribing. Please try again.")
      )
      return .none

    case .speech(.success(.availabilityDidChange)):
      return .none

    case let .speech(.success(.taskResult(result))):
      state.transcribedText = result.bestTranscription.formattedString
      return result.isFinal ? .cancel(id: CancelId.self) : .none

    case let .speechRecognizerAuthorizationStatusResponse(status):
      state.isRecording = status == .authorized
      state.speechRecognizerAuthorizationStatus = status

      switch status {
      case .authorized:
        return .run { send in
          do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            for try await action in await self.speechClient.recognitionTask(request) {
              await send(.speech(.success(action)))
            }
          } catch {
            await send(.speech(.failure(error)))
          }
        }

      case .denied:
        state.alert = AlertState(
          title: TextState(
            """
            You denied access to speech recognition. This app needs access to transcribe your \
            speech.
            """
          )
        )
        return .none

      case .notDetermined:
        return .none

      case .restricted:
        state.alert = AlertState(title: TextState("Your device does not allow speech recognition."))
        return .none

      @unknown default:
        return .none
      }
    }
  }
}

struct SpeechRecognitionView: View {
  let store: StoreOf<AppReducer>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding(.bottom, 32)

          Text(viewStore.transcribedText)
            .font(.largeTitle)
            .minimumScaleFactor(0.1)
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        }

        Spacer()

        Button(action: { viewStore.send(.recordButtonTapped) }) {
          HStack {
            Image(
              systemName: viewStore.isRecording
                ? "stop.circle.fill" : "arrowtriangle.right.circle.fill"
            )
            .font(.title)
            Text(viewStore.isRecording ? "Stop Recording" : "Start Recording")
          }
          .foregroundColor(.white)
          .padding()
          .background(viewStore.isRecording ? Color.red : .green)
          .cornerRadius(16)
        }
      }
      .padding()
      .alert(self.store.scope(state: \.alert), dismiss: .dismissAuthorizationStateAlert)
    }
  }
}

struct SpeechRecognitionView_Previews: PreviewProvider {
  static var previews: some View {
    SpeechRecognitionView(
      store: Store(
        initialState: AppReducer.State(transcribedText: "Test test 123"),
        reducer: AppReducer()
      )
    )
  }
}
