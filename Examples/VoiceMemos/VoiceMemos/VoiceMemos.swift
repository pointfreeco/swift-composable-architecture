import AVFoundation
import ComposableArchitecture
import SwiftUI

@Reducer
struct VoiceMemos {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var audioRecorderPermission = RecorderPermission.undetermined
    @Presents var recordingMemo: RecordingMemo.State?
    var voiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case onDelete(IndexSet)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recordingMemo(PresentationAction<RecordingMemo.Action>)
    case voiceMemos(IdentifiedActionOf<VoiceMemo>)

    enum Alert: Equatable {}
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.temporaryDirectory) var temporaryDirectory
  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .onDelete(indexSet):
        state.voiceMemos.remove(atOffsets: indexSet)
        return .none

      case .openSettingsButtonTapped:
        return .run { _ in
          await self.openSettings()
        }

      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .run { send in
            await send(.recordPermissionResponse(self.requestRecordPermission()))
          }

        case .denied:
          state.alert = AlertState { TextState("Permission is required to record voice memos.") }
          return .none

        case .allowed:
          state.recordingMemo = newRecordingMemo
          return .none
        }

      case let .recordingMemo(.presented(.delegate(.didFinish(.success(recordingMemo))))):
        state.recordingMemo = nil
        state.voiceMemos.insert(
          VoiceMemo.State(
            date: recordingMemo.date,
            duration: recordingMemo.duration,
            url: recordingMemo.url
          ),
          at: 0
        )
        return .none

      case .recordingMemo(.presented(.delegate(.didFinish(.failure)))):
        state.alert = AlertState { TextState("Voice memo recording failed.") }
        state.recordingMemo = nil
        return .none

      case .recordingMemo:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          state.recordingMemo = newRecordingMemo
          return .none
        } else {
          state.alert = AlertState { TextState("Permission is required to record voice memos.") }
          return .none
        }

      case let .voiceMemos(.element(id: id, action: .delegate(delegateAction))):
        switch delegateAction {
        case .playbackFailed:
          state.alert = AlertState { TextState("Voice memo playback failed.") }
          return .none
        case .playbackStarted:
          for memoID in state.voiceMemos.ids where memoID != id {
            state.voiceMemos[id: memoID]?.mode = .notPlaying
          }
          return .none
        }

      case .voiceMemos:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$recordingMemo, action: \.recordingMemo) {
      RecordingMemo()
    }
    .forEach(\.voiceMemos, action: \.voiceMemos) {
      VoiceMemo()
    }
  }

  private var newRecordingMemo: RecordingMemo.State {
    RecordingMemo.State(
      date: self.date.now,
      url: self.temporaryDirectory()
        .appendingPathComponent(self.uuid().uuidString)
        .appendingPathExtension("m4a")
    )
  }
}

struct VoiceMemosView: View {
  @Bindable var store: StoreOf<VoiceMemos>

  var body: some View {
    NavigationStack {
      VStack {
        List {
          ForEach(store.scope(state: \.voiceMemos, action: \.voiceMemos)) { store in
            VoiceMemoView(store: store)
          }
          .onDelete { store.send(.onDelete($0)) }
        }

        Group {
          if let store = store.scope(
            state: \.recordingMemo, action: \.recordingMemo.presented
          ) {
            RecordingMemoView(store: store)
          } else {
            RecordButton(permission: store.audioRecorderPermission) {
              store.send(.recordButtonTapped, animation: .spring())
            } settingsAction: {
              store.send(.openSettingsButtonTapped)
            }
          }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.init(white: 0.95))
      }
      .alert($store.scope(state: \.alert, action: \.alert))
      .navigationTitle("Voice memos")
    }
  }
}

struct RecordButton: View {
  let permission: VoiceMemos.State.RecorderPermission
  let action: () -> Void
  let settingsAction: () -> Void

  var body: some View {
    ZStack {
      Group {
        Circle()
          .foregroundColor(Color(.label))
          .frame(width: 74, height: 74)

        Button(action: action) {
          RoundedRectangle(cornerRadius: 35)
            .foregroundColor(Color(.systemRed))
            .padding(2)
        }
        .frame(width: 70, height: 70)
      }
      .opacity(permission == .denied ? 0.1 : 1)

      if permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: settingsAction)
        }
        .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
  }
}

#Preview {
  VoiceMemosView(
    store: Store(
      initialState: VoiceMemos.State(
        voiceMemos: [
          VoiceMemo.State(
            date: Date(),
            duration: 5,
            mode: .notPlaying,
            title: "Functions",
            url: URL(string: "https://www.pointfree.co/functions")!
          ),
          VoiceMemo.State(
            date: Date(),
            duration: 5,
            mode: .notPlaying,
            title: "",
            url: URL(string: "https://www.pointfree.co/untitled")!
          ),
        ]
      )
    ) {
      VoiceMemos()
    }
  )
}
