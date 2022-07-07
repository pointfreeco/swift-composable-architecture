import Combine
import ComposableArchitecture
import Speech
import SwiftUI

private let readMe = """
  This application demonstrates how to work with a complex dependency in the Composable \
  Architecture. It uses the SFSpeechRecognizer API from the Speech framework to listen to audio on \
  the device and live-transcribe it to the UI.
  """

struct AppState: Equatable {
  var alert: AlertState<AppAction>?
  var isRecording = false
  var transcribedText = ""
}

enum AppAction: Equatable {
  case dismissAuthorizationStateAlert
  case recordButtonTapped
  case speech(TaskResult<SpeechRecognitionResult>)
  case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
}

struct AppEnvironment {
  var speechClient: SpeechClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  enum CancelId {}

  switch action {
  case .dismissAuthorizationStateAlert:
    state.alert = nil
    return .none

  case .recordButtonTapped:
    state.isRecording.toggle()

    guard state.isRecording
    else { return .cancel(id: CancelId.self) }

    return .run { send in
      let status = await environment.speechClient.requestAuthorization()
      await send(.speechRecognizerAuthorizationStatusResponse(status))

      guard status == .authorized
      else { return }

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      request.requiresOnDeviceRecognition = false
      for try await action in environment.speechClient.recognitionTask(request) {
        await send(.speech(.success(action)))
      }
    } catch: { error, send in
      await send(.speech(.failure(error)))
    }
    .cancellable(id: CancelId.self)

  case .speech(.failure(SpeechClient.Failure.couldntConfigureAudioSession)),
    .speech(.failure(SpeechClient.Failure.couldntStartAudioEngine)):
    state.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    return .none

  case .speech(.failure):
    state.alert = AlertState(
      title: TextState("An error occurred while transcribing. Please try again.")
    )
    return .none

  case let .speech(.success(result)):
    state.transcribedText = result.bestTranscription.formattedString
    return .none

  case let .speechRecognizerAuthorizationStatusResponse(status):
    state.isRecording = status == .authorized

    switch status {
    case .authorized:
      return .none

    case .denied:
      state.alert = AlertState(
        title: TextState(
          """
          You denied access to speech recognition. This app needs access to transcribe your speech.
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

struct SpeechRecognitionView: View {
  let store: Store<AppState, AppAction>

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
        initialState: AppState(transcribedText: "Test test 123"),
        reducer: appReducer,
        environment: AppEnvironment(
          speechClient: .live
        )
      )
    )
  }
}
