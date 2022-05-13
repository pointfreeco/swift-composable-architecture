import AVFoundation
import ComposableArchitecture
import SwiftUI

struct VoiceMemos: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var audioRecorderPermission = RecorderPermission.undetermined
    var currentRecording: CurrentRecording?
    var voiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []

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

  enum Action: Equatable {
    case alertDismissed
    case audioRecorder(Result<AudioRecorderClient.Action, AudioRecorderClient.Failure>)
    case currentRecordingTimerUpdated
    case finalRecordingTime(TimeInterval)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case voiceMemo(id: VoiceMemo.State.ID, action: VoiceMemo.Action)
  }

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.mainRunLoop) var mainRunLoop
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.temporaryDirectory) var temporaryDirectory
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocol<State, Action> {
    ForEachReducer(state: \.voiceMemos, action: /Action.voiceMemo(id:action:)) {
      VoiceMemo()
    }

    Reduce { state, action in
      enum TimerId {}

      func startRecording() -> Effect<Action, Never> {
        let url = self.temporaryDirectory()
          .appendingPathComponent(self.uuid().uuidString)
          .appendingPathExtension("m4a")
        state.currentRecording = .init(
          date: self.mainRunLoop.now.date,
          url: url
        )

        return .merge(
          self.audioRecorder.startRecording(url)
            .catchToEffect(Action.audioRecorder),

          Effect.timer(id: TimerId.self, every: 1, tolerance: .zero, on: self.mainRunLoop)
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
          .init(
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
        return self.openSettings
          .fireAndForget()

      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return self.audioRecorder.requestRecordPermission()
            .map(Action.recordPermissionResponse)
            .receive(on: self.mainRunLoop)
            .eraseToEffect()

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

              self.audioRecorder.currentTime()
                .compactMap { $0 }
                .map(Action.finalRecordingTime)
                .eraseToEffect(),

              self.audioRecorder.stopRecording().fireAndForget()
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
  }
}

struct VoiceMemosView: View {
  let store: StoreOf<VoiceMemos>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationView {
        VStack {
          List {
            ForEachStore(
              self.store.scope(
                state: \.voiceMemos, action: VoiceMemos.Action.voiceMemo(id:action:)
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
        initialState: .init(
          voiceMemos: [
            .init(
              date: Date(),
              duration: 30,
              mode: .playing(progress: 0.3),
              title: "Functions",
              url: URL(string: "https://www.pointfree.co/functions")!
            ),
            .init(
              date: Date(),
              duration: 2,
              mode: .notPlaying,
              title: "",
              url: URL(string: "https://www.pointfree.co/untitled")!
            ),
          ]
        ),
        reducer: VoiceMemos()
          // NB: AVAudioRecorder doesn't work in previews, so we stub out the dependency here.
          .dependency(\.audioRecorder.currentTime) { Effect(value: 10) }
          .dependency(\.audioRecorder.requestRecordPermission) { Effect(value: true) }
          .dependency(\.audioRecorder.startRecording) { _ in .none }
          .dependency(\.audioRecorder.stopRecording) { .none }
          .dependency(\.openSettings, .none)
      )
    )
    .environment(\.colorScheme, .dark)
  }
}
