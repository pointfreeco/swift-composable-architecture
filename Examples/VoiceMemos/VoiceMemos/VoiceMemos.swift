import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemos: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<VoiceMemos.Action>?
    var audioRecorderPermission = RecorderPermission.undetermined
    var recordingMemo: RecordingMemo.State?
    var voiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []
  }
  enum RecorderPermission {
    case allowed
    case denied
    case undetermined
  }
  enum Action: Equatable {
    case alertDismissed
    case openSettingsButtonTapped
    case recordButtonTapped
    case recordPermissionResponse(Bool)
    case recordingMemo(RecordingMemo.Action)
    case voiceMemo(id: VoiceMemo.State.ID, action: VoiceMemo.Action)
  }
  var audioPlayer: AudioPlayerClient
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
  var openSettings: @Sendable () async -> Void
  var temporaryDirectory: @Sendable () -> URL
  var uuid: @Sendable () -> UUID

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    Reduce<State, Action> { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
        return .none

      case .openSettingsButtonTapped:
        return .fireAndForget {
          await self.openSettings()
        }

      case .recordButtonTapped:
        switch state.audioRecorderPermission {
        case .undetermined:
          return .task {
            await .recordPermissionResponse(self.audioRecorder.requestRecordPermission())
          }

        case .denied:
          state.alert = AlertState(title: TextState("Permission is required to record voice memos."))
          return .none

        case .allowed:
          state.recordingMemo = RecordingMemo.State(
            date: self.mainRunLoop.now.date,
            url: self.temporaryDirectory()
              .appendingPathComponent(self.uuid().uuidString)
              .appendingPathExtension("m4a")
          )
          return .none
        }

      case let .recordingMemo(.delegate(.didFinish(.success(recordingMemo)))):
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

      case .recordingMemo(.delegate(.didFinish(.failure))):
        state.alert = AlertState(title: TextState("Voice memo recording failed."))
        state.recordingMemo = nil
        return .none

      case .recordingMemo:
        return .none

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          state.recordingMemo = RecordingMemo.State(
            date: self.mainRunLoop.now.date,
            url: self.temporaryDirectory()
              .appendingPathComponent(self.uuid().uuidString)
              .appendingPathExtension("m4a")
          )
          return .none
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
    .ifLet(state: \State.recordingMemo, action: /Action.recordingMemo) {
      RecordingMemo(
        audioRecorder: self.audioRecorder,
        mainRunLoop: self.mainRunLoop
      )
    }
    .forEach(
      state: \State.voiceMemos,
      action: /Action.voiceMemo(id:action:)
    ) {
      VoiceMemo(
        audioPlayer: self.audioPlayer,
        mainRunLoop: self.mainRunLoop
      )
    }
    .reduce(into: &state, action: action)
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

          IfLetStore(
            self.store.scope(state: \.recordingMemo, action: { .recordingMemo($0) })
          ) { store in
            RecordingMemoView(store: store)
          } else: {
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
          self.store.scope(state: \.alert),
          dismiss: .alertDismissed
        )
        .navigationTitle("Voice memos")
      }
      .navigationViewStyle(.stack)
    }
  }
}

struct RecordButton: View {
  let permission: VoiceMemos.RecorderPermission
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
        reducer: Reducer(
          VoiceMemos(
            // NB: AVAudioRecorder and AVAudioPlayer doesn't work in previews, so use mocks
            //     that simulate their behavior in previews.
            audioPlayer: .mock,
            audioRecorder: .mock,
            mainRunLoop: .main,
            openSettings: {},
            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
            uuid: { UUID() }
          )
        ),
        environment: ()
      )
    )
  }
}

extension AudioRecorderClient {
  static var mock: Self {
    let isRecording = ActorIsolated(false)
    let currentTime = ActorIsolated(0.0)

    return Self(
      currentTime: { await currentTime.value },
      requestRecordPermission: { true },
      startRecording: { _ in
        await isRecording.setValue(true)
        while await isRecording.value {
          try await Task.sleep(nanoseconds: NSEC_PER_SEC)
          await currentTime.withValue { $0 += 1 }
        }
        return true
      },
      stopRecording: {
        await isRecording.setValue(false)
        await currentTime.setValue(0)
      }
    )
  }
}

extension AudioPlayerClient {
  static let mock = Self(
    play: { _ in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
      return true
    }
  )
}
