import AVFoundation
import ComposableArchitecture
import SwiftUI

struct VoiceMemosState: Equatable {
  var alert: AlertState<VoiceMemosAction>?
  var audioRecorderPermission = RecorderPermission.undetermined
  var currentRecording: CurrentRecording?
  var voiceMemos: [VoiceMemo] = []

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
  case audioRecorderClient(Result<AudioRecorderClient.Action, AudioRecorderClient.Failure>)
  case currentRecordingTimerUpdated
  case finalRecordingTime(TimeInterval)
  case openSettingsButtonTapped
  case recordButtonTapped
  case recordPermissionBlockCalled(Bool)
  case voiceMemo(index: Int, action: VoiceMemoAction)
}

struct VoiceMemosEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var audioRecorderClient: AudioRecorderClient
  var date: () -> Date
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var openSettings: Effect<Never, Never>
  var temporaryDirectory: () -> URL
  var uuid: () -> UUID
}

let voiceMemosReducer = Reducer<VoiceMemosState, VoiceMemosAction, VoiceMemosEnvironment>.combine(
  voiceMemoReducer.forEach(
    state: \.voiceMemos,
    action: /VoiceMemosAction.voiceMemo(index:action:),
    environment: {
      VoiceMemoEnvironment(audioPlayerClient: $0.audioPlayerClient, mainQueue: $0.mainQueue)
    }),
  .init { state, action, environment in
    struct RecorderId: Hashable {}
    struct RecorderTimerId: Hashable {}

    func startRecording() -> Effect<VoiceMemosAction, Never> {
      let url = environment.temporaryDirectory()
        .appendingPathComponent(environment.uuid().uuidString)
        .appendingPathExtension("m4a")
      state.currentRecording = .init(
        date: environment.date(),
        url: url
      )
      return .merge(
        environment.audioRecorderClient.startRecording(RecorderId(), url)
          .catchToEffect()
          .map(VoiceMemosAction.audioRecorderClient),
        Effect.timer(id: RecorderTimerId(), every: 1, tolerance: .zero, on: environment.mainQueue)
          .map { _ in .currentRecordingTimerUpdated }
      )
    }

    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .audioRecorderClient(.success(.didFinishRecording(successfully: true))):
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

    case .audioRecorderClient(.success(.didFinishRecording(successfully: false))),
      .audioRecorderClient(.failure):
      state.alert = .init(title: "Voice memo recording failed.")
      state.currentRecording = nil
      return .cancel(id: RecorderTimerId())

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
        return environment.audioRecorderClient.requestRecordPermission()
          .map(VoiceMemosAction.recordPermissionBlockCalled)
          .receive(on: environment.mainQueue)
          .eraseToEffect()

      case .denied:
        state.alert = .init(title: "Permission is required to record voice memos.")
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
            .cancel(id: RecorderTimerId()),
            environment.audioRecorderClient.currentTime(RecorderId())
              .compactMap { $0 }
              .map(VoiceMemosAction.finalRecordingTime)
              .eraseToEffect(),
            environment.audioRecorderClient.stopRecording(RecorderId())
              .fireAndForget()
          )
        }
      }

    case let .recordPermissionBlockCalled(permission):
      state.audioRecorderPermission = permission ? .allowed : .denied
      if permission {
        return startRecording()
      } else {
        state.alert = .init(title: "Permission is required to record voice memos.")
        return .none
      }

    case .voiceMemo(index: _, action: .audioPlayerClient(.failure)):
      state.alert = .init(title: "Voice memo playback failed.")
      return .none

    case let .voiceMemo(index: index, action: .delete):
      state.voiceMemos.remove(at: index)
      return .none

    case let .voiceMemo(index: index, action: .playButtonTapped):
      for idx in state.voiceMemos.indices where idx != index {
        state.voiceMemos[idx].mode = .notPlaying
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
                state: { $0.voiceMemos }, action: VoiceMemosAction.voiceMemo(index:action:)
              ),
              id: \.url,
              content: VoiceMemoView.init(store:)
            )
            .onDelete { indexSet in
              for index in indexSet {
                viewStore.send(.voiceMemo(index: index, action: .delete))
              }
            }
          }
          VStack {
            ZStack {
              Circle()
                .foregroundColor(Color(.label))
                .frame(width: 74, height: 74)

              Button(
                action: {
                  withAnimation(.spring()) {
                    viewStore.send(.recordButtonTapped)
                  }
                }
              ) {
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

            (viewStore.currentRecording?.duration).map { duration in
              dateComponentsFormatter.string(from: duration).map {
                Text($0)
                  .font(Font.body.monospacedDigit().bold())
                  .foregroundColor(.white)
                  .colorMultiply(Color(Int(duration).isMultiple(of: 2) ? .systemRed : .label))
                  .animation(.easeInOut(duration: 0.5))
              }
            }
          }
          .padding()
        }
        .alert(
          self.store.scope(state: { $0.alert }),
          dismiss: .alertDismissed
        )
        .navigationBarTitle("Voice memos")
      }
      .navigationViewStyle(StackNavigationViewStyle())
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
          audioPlayerClient: .live,
          // NB: AVAudioRecorder doesn't work in previews, so we stub out the dependency here.
          audioRecorderClient: .init(
            currentTime: { _ in Effect(value: 10) },
            requestRecordPermission: { Effect(value: true) },
            startRecording: { _, _ in .none },
            stopRecording: { _ in .none }
          ),
          date: Date.init,
          mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
          openSettings: .none,
          temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
          uuid: UUID.init
        )
      )
    )
    .environment(\.colorScheme, .dark)
  }
}
