import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemosState: Equatable {
  var alert: AlertState<VoiceMemosAction>?
  var audioRecorderPermission = RecorderPermission.undetermined
  var currentRecording: CurrentRecording?
  var voiceMemos: IdentifiedArrayOf<VoiceMemoState> = []

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
  case audioRecorderDidFinish(TaskResult<Bool>)
  case currentRecordingTimerUpdated
  case finalRecordingTime(TimeInterval)
  case openSettingsButtonTapped
  case recordButtonTapped
  case recordPermissionResponse(Bool)
  case voiceMemo(id: VoiceMemoState.ID, action: VoiceMemoAction)
}

struct VoiceMemosEnvironment {
  var audioPlayer: AudioPlayerClient
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var openSettings: @Sendable () async -> Void
  var temporaryDirectory: @Sendable () -> URL
  var uuid: @Sendable () -> UUID
}

let voiceMemosReducer = Reducer<VoiceMemosState, VoiceMemosAction, VoiceMemosEnvironment>.combine(
  voiceMemoReducer.forEach(
    state: \.voiceMemos,
    action: /VoiceMemosAction.voiceMemo(id:action:),
    environment: {
      VoiceMemoEnvironment(audioPlayerClient: $0.audioPlayer, mainRunLoop: $0.mainRunLoop)
    }
  ),
  Reducer { state, action, environment in
    enum RecordID {}

    func startRecording() -> Effect<VoiceMemosAction, Never> {
      let url = environment.temporaryDirectory()
        .appendingPathComponent(environment.uuid().uuidString)
        .appendingPathExtension("m4a")
      state.currentRecording = VoiceMemosState.CurrentRecording(
        date: environment.mainRunLoop.now.date,
        url: url
      )

      return .run { send in
        async let startRecording: Void = await send(
          .audioRecorderDidFinish(
            TaskResult { try await environment.audioRecorder.startRecording(url) }
          )
        )

        for await _ in environment.mainRunLoop.timer(interval: .seconds(1)) {
          await send(.currentRecordingTimerUpdated)
        }
      }
      .cancellable(id: RecordID.self, cancelInFlight: true)
    }

    switch action {
    case .alertDismissed:
      state.alert = nil
      return .none

    case .audioRecorderDidFinish(.success(true)):
      guard
        let currentRecording = state.currentRecording,
        currentRecording.mode == .encoding
      else {
        assertionFailure()
        return .none
      }

      state.currentRecording = nil
      state.voiceMemos.insert(
        VoiceMemoState(
          date: currentRecording.date,
          duration: currentRecording.duration,
          url: currentRecording.url
        ),
        at: 0
      )
      return .cancel(id: RecordID.self)

    case .audioRecorderDidFinish(.success(false)), .audioRecorderDidFinish(.failure):
      state.alert = AlertState(title: TextState("Voice memo recording failed."))
      state.currentRecording = nil
      return .cancel(id: RecordID.self)

    case .currentRecordingTimerUpdated:
      state.currentRecording?.duration += 1
      return .none

    case let .finalRecordingTime(duration):
      state.currentRecording?.duration = duration
      return .none

    case .openSettingsButtonTapped:
      return .fireAndForget {
        await environment.openSettings()
      }

    case .recordButtonTapped:
      switch state.audioRecorderPermission {
      case .undetermined:
        return .task {
          await .recordPermissionResponse(environment.audioRecorder.requestRecordPermission())
        }

      case .denied:
        state.alert = AlertState(title: TextState("Permission is required to record voice memos."))
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

          return .run { send in
            if let currentTime = await environment.audioRecorder.currentTime() {
              await send(.finalRecordingTime(currentTime))
            }
            await environment.audioRecorder.stopRecording()
          }
        }
      }

    case let .recordPermissionResponse(permission):
      state.audioRecorderPermission = permission ? .allowed : .denied
      if permission {
        return startRecording()
      } else {
        state.alert = AlertState(title: TextState("Permission is required to record voice memos."))
        return .none
      }

    case .voiceMemo(id: _, action: .audioPlayerClient(.failure)):
      state.alert = AlertState(title: TextState("Voice memo playback failed."))
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
              )
            ) {
              VoiceMemoView(store: $0)
            }
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
        .navigationTitle("Voice memos")
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
            VoiceMemoState(
              date: Date(),
              duration: 30,
              mode: .playing(progress: 0.3),
              title: "Functions",
              url: URL(string: "https://www.pointfree.co/functions")!
            ),
            VoiceMemoState(
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
          audioRecorder: AudioRecorderClient(
            currentTime: { 10 },
            requestRecordPermission: { true },
            startRecording: { _ in try await Task.never() },
            stopRecording: {}
          ),
          mainRunLoop: .main,
          openSettings: {},
          temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
          uuid: { UUID() }
        )
      )
    )
    .environment(\.colorScheme, .dark)
  }
}
