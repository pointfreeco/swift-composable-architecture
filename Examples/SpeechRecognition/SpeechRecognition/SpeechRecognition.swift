import ComposableArchitecture
import Speech
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a complex dependency in the Composable \
  Architecture. It uses the `SFSpeechRecognizer` API from the Speech framework to listen to audio \
  on the device and live-transcribe it to the UI.
  """

@Reducer
struct SpeechRecognition {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    var isRecording = false
    var transcribedText = ""
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case recordButtonTapped
    case speech(Result<String, Error>)
    case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)

    enum Alert: Equatable {}
  }

  @Dependency(\.speechClient) var speechClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .recordButtonTapped:
        state.isRecording.toggle()

        guard state.isRecording
        else {
          return .run { _ in
            await self.speechClient.finishTask()
          }
        }

        return .run { send in
          let status = await self.speechClient.requestAuthorization()
          await send(.speechRecognizerAuthorizationStatusResponse(status))

          guard status == .authorized
          else { return }

          let request = SFSpeechAudioBufferRecognitionRequest()
          for try await result in await self.speechClient.startTask(request) {
            await send(
              .speech(.success(result.bestTranscription.formattedString)), animation: .linear)
          }
        } catch: { error, send in
          await send(.speech(.failure(error)))
        }

      case .speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession)),
        .speech(.failure(SpeechClient.Failure.couldntStartAudioEngine)):
        state.alert = AlertState { TextState("Problem with audio device. Please try again.") }
        return .none

      case .speech(.failure):
        state.alert = AlertState {
          TextState("An error occurred while transcribing. Please try again.")
        }
        return .none

      case let .speech(.success(transcribedText)):
        state.transcribedText = transcribedText
        return .none

      case let .speechRecognizerAuthorizationStatusResponse(status):
        state.isRecording = status == .authorized

        switch status {
        case .authorized:
          return .none

        case .denied:
          state.alert = AlertState {
            TextState(
              """
              You denied access to speech recognition. This app needs access to transcribe your \
              speech.
              """
            )
          }
          return .none

        case .notDetermined:
          return .none

        case .restricted:
          state.alert = AlertState { TextState("Your device does not allow speech recognition.") }
          return .none

        @unknown default:
          return .none
        }
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

struct SpeechRecognitionView: View {
  let store: StoreOf<SpeechRecognition>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      VStack {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding(.bottom, 32)
        }

        ScrollView {
          ScrollViewReader { proxy in
            Text(viewStore.transcribedText)
              .font(.largeTitle)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        Spacer()

        Button {
          viewStore.send(.recordButtonTapped)
        } label: {
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
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
    }
  }
}

struct SpeechRecognitionView_Previews: PreviewProvider {
  static var previews: some View {
    SpeechRecognitionView(
      store: Store(initialState: SpeechRecognition.State(transcribedText: "Test test 123")) {
        SpeechRecognition()
      }
    )
  }
}
