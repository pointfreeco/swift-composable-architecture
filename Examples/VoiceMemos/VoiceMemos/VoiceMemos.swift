import AVFoundation
import ComposableArchitecture
import SwiftUI

struct VoiceMemos: ReducerProtocol {
  struct State: Equatable {
    var audioRecorderPermission = RecorderPermission.undetermined
    @PresentationStateOf<Destinations> var destination
    var voiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []

    enum RecorderPermission {
      case allowed
      case denied
      case undetermined
    }
  }
  enum Action: Equatable {
    case destination(PresentationActionOf<Destinations>)
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case voiceMemo(id: VoiceMemo.State.ID, action: VoiceMemo.Action)
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      case alert(AlertState<Never>)
      case recordingMemo(RecordingMemo.State)
    }
    enum Action: Equatable {
      case alert(Never)
      case recordingMemo(RecordingMemo.Action)
    }
    var body: some ReducerProtocolOf<Self> {
      Scope(state: /State.recordingMemo, action: /Action.recordingMemo) {
        RecordingMemo()
      }
    }
  }

  @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
  @Dependency(\.date) var date
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.temporaryDirectory) var temporaryDirectory
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocol<State, Action> {
    Reduce(self.core)
      .presentationDestination(\.$destination, action: /Action.destination) {
        Destinations()
      }
      .forEach(\.voiceMemos, action: /Action.voiceMemo(id:action:)) {
        VoiceMemo()
      }
  }

  private func core(state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case let .destination(.presented(.recordingMemo(.delegate(delegate)))):
      switch delegate {
      case let .didFinish(.success(recordingMemo)):
        state.destination = nil
        state.voiceMemos.insert(
          VoiceMemo.State(
            date: recordingMemo.date,
            duration: recordingMemo.duration,
            url: recordingMemo.url
          ),
          at: 0
        )
        return .none

      case .didFinish(.failure):
        state.destination = .alert(.recordingFailed)
        return .none
      }

    case .destination(.present(id: _, _)):
      // TODO: let's chat more about this
      return .none

    case .destination:
      return .none

    case .openSettingsButtonTapped:
      return .fireAndForget {
        await self.openSettings()
      }

    case .recordButtonTapped:
      switch state.audioRecorderPermission {
      case .undetermined:
        return .task {
          await .recordPermissionResponse(self.requestRecordPermission())
        }

      case .denied:
        state.destination = .alert(.permissionRequired)
        return .none

      case .allowed:
        state.destination = .recordingMemo(newRecordingMemo)
        return .none
      }

    case let .recordPermissionResponse(permission):
      state.audioRecorderPermission = permission ? .allowed : .denied
      if permission {
        state.destination = .recordingMemo(newRecordingMemo)
        return .none
      } else {
        state.destination = .alert(.permissionRequired)
        return .none
      }

    case .voiceMemo(id: _, action: .audioPlayerClient(.failure)):
      state.destination = .alert(.playbackFailed)
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

  private var newRecordingMemo: RecordingMemo.State {
    RecordingMemo.State(
      date: self.date.now,
      url: self.temporaryDirectory()
        .appendingPathComponent(self.uuid().uuidString)
        .appendingPathExtension("m4a")
    )
  }
}

extension AlertState where Action == Never {
  static let permissionRequired = AlertState {
    TextState("Permission is required to record voice memos.")
  }

  static let recordingFailed = AlertState {
    TextState("Voice memo recording failed.")
  }

  static let playbackFailed = AlertState {
    TextState("Voice memo playback failed.")
  }
}

struct VoiceMemosView: View {
  let store: StoreOf<VoiceMemos>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      NavigationView {
        VStack {
          List {
            ForEachStore(
              self.store.scope(state: \.voiceMemos, action: { .voiceMemo(id: $0, action: $1) })
            ) {
              VoiceMemoView(store: $0)
            }
            .onDelete { indexSet in
              for index in indexSet {
                viewStore.send(.voiceMemo(id: viewStore.voiceMemos[index].id, action: .delete))
              }
            }
          }

          PresentedView(
            self.store.scope(state: \.$destination, action: VoiceMemos.Action.destination),
            state: /VoiceMemos.Destinations.State.recordingMemo,
            action: VoiceMemos.Destinations.Action.recordingMemo
          ) { store in
            RecordingMemoView(store: store)
          } dismissed: {
            RecordButton(permission: viewStore.audioRecorderPermission) {
              viewStore.send(.recordButtonTapped, animation: .spring())
            } settingsAction: {
              viewStore.send(.openSettingsButtonTapped)
            }
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.init(white: 0.95))
        }
        .alert(
          store: self.store.scope(state: \.$destination, action: VoiceMemos.Action.destination),
          state: /VoiceMemos.Destinations.State.alert,
          action: VoiceMemos.Destinations.Action.alert
        )
        .navigationTitle("Voice memos")
      }
      .navigationViewStyle(.stack)
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

        Button(action: self.action) {
          RoundedRectangle(cornerRadius: 35)
            .foregroundColor(Color(.systemRed))
            .padding(2)
        }
        .frame(width: 70, height: 70)
      }
      .opacity(self.permission == .denied ? 0.1 : 1)

      if self.permission == .denied {
        VStack(spacing: 10) {
          Text("Recording requires microphone access.")
            .multilineTextAlignment(.center)
          Button("Open Settings", action: self.settingsAction)
        }
        .frame(maxWidth: .infinity, maxHeight: 74)
      }
    }
  }
}

struct VoiceMemos_Previews: PreviewProvider {
  static var previews: some View {
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
        ),
        reducer: VoiceMemos()
      )
    )
  }
}
