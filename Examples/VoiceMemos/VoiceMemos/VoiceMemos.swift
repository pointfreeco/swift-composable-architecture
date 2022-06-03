import AVFoundation
import ComposableArchitecture
import SwiftUI

struct VoiceMemosState: Equatable {
  var alert: AlertState<VoiceMemosAction>?
  var audioRecorderPermission = RecorderPermission.undetermined
  var currentRecording: CurrentRecording?
  var voiceMemos: IdentifiedArrayOf<VoiceMemo> = []

  struct CurrentRecording: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL

    enum Mode {
      case recording
      case encoding
    }
  }

  enum RecorderPermission {
    case allowed
    case denied
    case undetermined
  }
}

enum VoiceMemosAction: Equatable {
  case alertDismissed
  case audioRecorder(Result<AudioRecorderClient.Action, AudioRecorderClient.Failure>)
  case currentRecordingTimerUpdated
  case finalRecordingTime(TimeInterval)
  case openSettingsButtonTapped
  case recordButtonTapped
  case recordPermissionResponse(Bool)
  case voiceMemo(id: VoiceMemo.ID, action: VoiceMemoAction)
}

struct VoiceMemosEnvironment {
  var audioPlayer: AudioPlayerClient
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var openSettings: Effect<Never, Never>
  var temporaryDirectory: () -> URL
  var uuid: () -> UUID
}

let voiceMemosReducer = Reducer<VoiceMemosState, VoiceMemosAction, VoiceMemosEnvironment>.combine(
  voiceMemoReducer.forEach(
    state: \.voiceMemos,
    action: /VoiceMemosAction.voiceMemo(id:action:),
    environment: {
      VoiceMemoEnvironment(audioPlayerClient: $0.audioPlayer, mainRunLoop: $0.mainRunLoop)
    }
  ),
  .init { state, action, environment in
    enum TimerId {}

    func startRecording() -> Effect<VoiceMemosAction, Never> {
      let url = environment.temporaryDirectory()
        .appendingPathComponent(environment.uuid().uuidString)
        .appendingPathExtension("m4a")
      state.currentRecording = .init(
        date: environment.mainRunLoop.now.date,
        url: url
      )

      return .merge(
        environment.audioRecorder.startRecording(url)
          .catchToEffect(VoiceMemosAction.audioRecorder),

        Effect.timer(id: TimerId.self, every: 1, tolerance: .zero, on: environment.mainRunLoop)
          .map { _ in .currentRecordingTimerUpdated }
      )
    }

    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .audioRecorder(.success(.didFinishRecording(successfully: true))):
      guard
        let currentRecording = state.currentRecording,
        currentRecording.mode == .encoding
      else {
        assertionFailure()
        return .none
      }

      state.currentRecording = nil
      state.voiceMemos.insert(
        VoiceMemo(
          date: currentRecording.date,
          duration: currentRecording.duration,
          url: currentRecording.url
        ),
        at: 0
      )
      return .none

    case .audioRecorder(.success(.didFinishRecording(successfully: false))),
      .audioRecorder(.failure):
      state.alert = .init(title: .init("Voice memo recording failed."))
      state.currentRecording = nil
      return .cancel(id: TimerId.self)

    case .currentRecordingTimerUpdated:
      state.currentRecording?.duration += 1
      return .none

    case let .finalRecordingTime(duration):
      state.currentRecording?.duration = duration
      return .none

    case .openSettingsButtonTapped:
      return environment.openSettings
        .fireAndForget()

    case .recordButtonTapped:
      switch state.audioRecorderPermission {
      case .undetermined:
        return environment.audioRecorder.requestRecordPermission()
          .receive(on: environment.mainRunLoop)
          .eraseToEffect(VoiceMemosAction.recordPermissionResponse)

      case .denied:
        state.alert = .init(title: .init("Permission is required to record voice memos."))
        return .none

      case .allowed:
        guard let currentRecording = state.currentRecording else {
          return startRecording()
        }

        switch currentRecording.mode {
        case .encoding:
          return .none

        case .recording:
          state.currentRecording?.mode = .encoding
          return .concatenate(
            .cancel(id: TimerId.self),

            environment.audioRecorder.currentTime()
              .compactMap { $0 }
              .eraseToEffect(VoiceMemosAction.finalRecordingTime),

            environment.audioRecorder.stopRecording().fireAndForget()
          )
        }
      }

    case let .recordPermissionResponse(permission):
      state.audioRecorderPermission = permission ? .allowed : .denied
      if permission {
        return startRecording()
      } else {
        state.alert = .init(title: .init("Permission is required to record voice memos."))
        return .none
      }

    case .voiceMemo(id: _, action: .audioPlayerClient(.failure)):
      state.alert = .init(title: .init("Voice memo playback failed."))
      return .none

    case let .voiceMemo(id: id, action: .delete):
      state.voiceMemos.remove(id: id)
      return .none

    case let .voiceMemo(id: tappedId, action: .playButtonTapped):
      for id in state.voiceMemos.ids where id != tappedId {
        state.voiceMemos[id: id]?.mode = .notPlaying
      }
      return .none

    case .voiceMemo:
      return .none
    }
  }
)

struct VoiceMemosView: View {
  let store: Store<VoiceMemosState, VoiceMemosAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationView {
        VStack {
          List {
            ForEachStore(
              self.store.scope(
                state: \.voiceMemos, action: VoiceMemosAction.voiceMemo(id:action:)
              ),
              content: VoiceMemoView.init(store:)
            )
            .onDelete { indexSet in
              for index in indexSet {
                viewStore.send(.voiceMemo(id: viewStore.voiceMemos[index].id, action: .delete))
              }
            }
          }
          VStack {
            ZStack {
              Circle()
                .foregroundColor(Color(.label))
                .frame(width: 74, height: 74)

              Button(action: { viewStore.send(.recordButtonTapped, animation: .spring()) }) {
                RoundedRectangle(cornerRadius: viewStore.currentRecording != nil ? 4 : 35)
                  .foregroundColor(Color(.systemRed))
                  .padding(viewStore.currentRecording != nil ? 17 : 2)
              }
              .frame(width: 70, height: 70)

              if viewStore.state.audioRecorderPermission == .denied {
                VStack(spacing: 10) {
                  Text("Recording requires microphone access.")
                    .multilineTextAlignment(.center)
                  Button("Open Settings") { viewStore.send(.openSettingsButtonTapped) }
                }
                .frame(maxWidth: .infinity, maxHeight: 74)
                .background(Color.white.opacity(0.9))
              }
            }

            if let duration = viewStore.currentRecording?.duration,
              let formattedDuration = dateComponentsFormatter.string(from: duration)
            {
              Text(formattedDuration)
                .font(.body.monospacedDigit().bold())
                .foregroundColor(.white)
                .colorMultiply(Color(Int(duration).isMultiple(of: 2) ? .systemRed : .label))
                .animation(.easeInOut(duration: 0.5), value: duration)
            }
          }
          .padding()
        }
        .alert(
          self.store.scope(state: \.alert),
          dismiss: .alertDismissed
        )
        .navigationBarTitle("Voice memos")
      }
      .navigationViewStyle(.stack)
    }
  }
}

struct VoiceMemos_Previews: PreviewProvider {
  static var previews: some View {
    VoiceMemosView(
      store: Store(
        initialState: VoiceMemosState(
          voiceMemos: [
            VoiceMemo(
              date: Date(),
              duration: 30,
              mode: .playing(progress: 0.3),
              title: "Functions",
              url: URL(string: "https://www.pointfree.co/functions")!
            ),
            VoiceMemo(
              date: Date(),
              duration: 2,
              mode: .notPlaying,
              title: "",
              url: URL(string: "https://www.pointfree.co/untitled")!
            ),
          ]
        ),
        reducer: voiceMemosReducer,
        environment: VoiceMemosEnvironment(
          audioPlayer: .live,
          // NB: AVAudioRecorder doesn't work in previews, so we stub out the dependency here.
          audioRecorder: .init(
            currentTime: { Effect(value: 10) },
            requestRecordPermission: { Effect(value: true) },
            startRecording: { _ in .none },
            stopRecording: { .none }
          ),
          mainRunLoop: .main,
          openSettings: .none,
          temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
          uuid: UUID.init
        )
      )
    )
    .environment(\.colorScheme, .dark)
  }
}
