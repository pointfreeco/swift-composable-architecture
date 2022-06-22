import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemos: ReducerProtocol, Sendable {
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
    case audioRecorderDidFinish(TaskResult<Bool>)
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
    Reduce { state, action in
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
          .init(
            date: currentRecording.date,
            duration: currentRecording.duration,
            url: currentRecording.url
          ),
          at: 0
        )
        return .cancel(id: RecordId.self)

      case .audioRecorderDidFinish(.success(false)), .audioRecorderDidFinish(.failure):
        state.alert = .init(title: .init("Voice memo recording failed."))
        state.currentRecording = nil
        return .cancel(id: RecordId.self)

      case .currentRecordingTimerUpdated:
        state.currentRecording?.duration += 1
        return .none

      case let .finalRecordingTime(duration):
        state.currentRecording?.duration = duration
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
          state.alert = .init(title: .init("Permission is required to record voice memos."))
          return .none

        case .allowed:
          guard let currentRecording = state.currentRecording else {
            return self.startRecording(state: &state)
          }

          switch currentRecording.mode {
          case .encoding:
            return .none

          case .recording:
            state.currentRecording?.mode = .encoding

            return .run { send in
              if let currentTime = await self.audioRecorder.currentTime() {
                await send(.finalRecordingTime(currentTime))
              }
              await self.audioRecorder.stopRecording()
            }
          }
        }

      case let .recordPermissionResponse(permission):
        state.audioRecorderPermission = permission ? .allowed : .denied
        if permission {
          return self.startRecording(state: &state)
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
    .forEach(state: \.voiceMemos, action: /Action.voiceMemo(id:action:)) {
      VoiceMemo()
    }
  }

  private func startRecording(state: inout State) -> Effect<Action, Never> {
    let url = self.temporaryDirectory()
      .appendingPathComponent(self.uuid().uuidString)
      .appendingPathExtension("m4a")
    state.currentRecording = .init(
      date: self.mainRunLoop.now.date,
      url: url
    )

    return .run { send in
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await send(
            .audioRecorderDidFinish(.init { try await self.audioRecorder.startRecording(url) })
          )
        }
        group.addTask {
          for await _ in self.mainRunLoop.timer(interval: .seconds(1)) {
            await send(.currentRecordingTimerUpdated)
          }
        }
      }
    }
    .cancellable(id: RecordId.self, cancelInFlight: true)
  }

  private enum RecordId {}
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
          .dependency(\.audioRecorder.currentTime) { 10 }
          .dependency(\.audioRecorder.requestRecordPermission) { true }
          .dependency(\.audioRecorder.startRecording) { _ in true }
          .dependency(\.audioRecorder.stopRecording) {}
          .dependency(\.openSettings) {}
      )
    )
    .environment(\.colorScheme, .dark)
  }
}
