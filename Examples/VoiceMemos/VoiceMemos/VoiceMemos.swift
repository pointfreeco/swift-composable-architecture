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

//  var audioPlayer: AudioPlayerClient
//  var audioRecorder: AudioRecorderClient
//  var mainRunLoop: AnySchedulerOf<RunLoop>
//  var openSettings: @Sendable () async -> Void
//  var temporaryDirectory: @Sendable () -> URL
//  var uuid: @Sendable () -> UUID

//  @Dependency(\.audioPlayer) private var audioPlayer
  @Dependency(\.audioRecorder.requestRecordPermission) private var requestRecordPermission
  @Dependency(\.mainRunLoop) private var mainRunLoop
  @Dependency(\.openSettings) private var openSettings
  @Dependency(\.temporaryDirectory) private var temporaryDirectory
  @Dependency(\.uuid) private var uuid

  public init() {}

  var body: some ReducerProtocol<State, Action> {
    Reduce(self.core)
      .ifLet(state: \.recordingMemo, action: /Action.recordingMemo) {
        RecordingMemo()
          //.dependency(\.audioRecorder, .onboarding)
      }
      .forEach(
        state: \.voiceMemos,
        action: /Action.voiceMemo(id:action:)
      ) {
        VoiceMemo()
      }
  }

  func core(state: inout State, action: Action) -> Effect<Action, Never> {
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
          await .recordPermissionResponse(self.requestRecordPermission())
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
              .environment(\.myValue, 1729)
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
          VoiceMemos()
//          (
//            // NB: AVAudioRecorder and AVAudioPlayer doesn't work in previews, so use mocks
//            //     that simulate their behavior in previews.
//            audioPlayer: .mock,
//            audioRecorder: .mock,
//            mainRunLoop: .main,
//            openSettings: {},
//            temporaryDirectory: { URL(fileURLWithPath: NSTemporaryDirectory()) },
//            uuid: { UUID() }
//          )
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



//struct Foo {
//  var value = 42
//  var void = ()
//  subscript(hashable value: Int) -> Int { value }
//  subscript(void value: Void) -> Void { value }
//}
//let kp1: any Hashable = \Foo.value
//let kp2: any Hashable = \Foo.void
//let kp3: any Hashable = \Foo.[hashable: 1]
////let kp4 = \Foo.[void: ()]
//
//let kp5: any Sendable = \Foo.value
//let kp6: any Sendable = \Foo.void
