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
  case speech(Result<String, SpeechClient.Error>)
  case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
}

struct AppEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var speechClient: SpeechClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .dismissAuthorizationStateAlert:
    state.alert = nil
    return .none

  case .speech(.failure(.couldntConfigureAudioSession)),
    .speech(.failure(.couldntStartAudioEngine)):
    state.alert = AlertState(title: TextState("Problem with audio device. Please try again."))
    return .none

  case .recordButtonTapped:
    state.isRecording.toggle()
    if state.isRecording {
      return environment.speechClient.requestAuthorization()
        .receive(on: environment.mainQueue)
        .eraseToEffect(AppAction.speechRecognizerAuthorizationStatusResponse)
    } else {
      return environment.speechClient.finishTask()
        .fireAndForget()
    }

  case let .speech(.success(transcribedText)):
    state.transcribedText = transcribedText
    return .none

  case let .speech(.failure(error)):
    state.alert = AlertState(
      title: TextState("An error occurred while transcribing. Please try again.")
    )
    return environment.speechClient.finishTask()
      .fireAndForget()

  case let .speechRecognizerAuthorizationStatusResponse(status):
    state.isRecording = status == .authorized

    switch status {
    case .notDetermined:
      state.alert = AlertState(title: TextState("Try again."))
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

    case .restricted:
      state.alert = AlertState(title: TextState("Your device does not allow speech recognition."))
      return .none

    case .authorized:
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      request.requiresOnDeviceRecognition = false
      return environment.speechClient.startTask(request)
        .map(\.bestTranscription.formattedString)
        .animation()
        .catchToEffect(AppAction.speech)

    @unknown default:
      return .none
    }
  }
}
.debug()

struct AuthorizationStateAlert: Equatable, Identifiable {
  var title: String

  var id: String { self.title }
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
          mainQueue: .main,
          speechClient: .lorem
        )
      )
    )
  }
}

extension SpeechClient {
  static var lorem: Self {
    var isRunning = false
    return Self(
      finishTask: {
        .fireAndForget {
          isRunning = false
        }
      },
      requestAuthorization: {
        .init(value: .authorized)
      },
      startTask: { _ in
        isRunning = true
        var finalText = """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
          dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
          Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
          mollit anim id est laborum.
          """
        var text = ""

        return .run { subscriber in
          return Timer.publish(every: 0.33, on: .main, in: .default)
            .autoconnect()
            .prefix { _ in !finalText.isEmpty && isRunning }
            .sink { _ in
              let word = finalText.prefix { $0 != " " }
              finalText.removeFirst(word.count)
              if finalText.first == " " {
                finalText.removeFirst()
              }
              text += word + " "
              subscriber.send(
                .init(
                  bestTranscription: .init(
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
    )
  }
}
