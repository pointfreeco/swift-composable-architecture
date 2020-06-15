import AVFoundation
import ComposableArchitecture
import SwiftUI

struct VoiceMemo: Equatable {
  var date: Date
  var duration: TimeInterval
  var mode = Mode.notPlaying
  var title = ""
  var url: URL

  enum Mode: Equatable {
    case notPlaying
    case playing(progress: Double)

    var isPlaying: Bool {
      if case .playing = self { return true }
      return false
    }

    var progress: Double? {
      if case let .playing(progress) = self { return progress }
      return nil
    }
  }
}

enum VoiceMemoAction: Equatable {
  case audioPlayerClient(Result<AudioPlayerClient.Action, AudioPlayerClient.Failure>)
  case playButtonTapped
  case delete
  case timerUpdated(TimeInterval)
  case titleTextFieldChanged(String)
}

struct VoiceMemoEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let voiceMemoReducer = Reducer<VoiceMemo, VoiceMemoAction, VoiceMemoEnvironment> {
  memo, action, environment in
  struct PlayerId: Hashable {}
  struct TimerId: Hashable {}

  switch action {
  case .audioPlayerClient(.success(.didFinishPlaying)), .audioPlayerClient(.failure):
    memo.mode = .notPlaying
    return .cancel(id: TimerId())

  case .delete:
    return .merge(
      .cancel(id: PlayerId()),
      .cancel(id: TimerId())
    )

  case .playButtonTapped:
    switch memo.mode {
    case .notPlaying:
      memo.mode = .playing(progress: 0)
      let start = environment.mainQueue.now
      return .merge(
        environment.audioPlayerClient
          .play(PlayerId(), memo.url)
          .catchToEffect()
          .map(VoiceMemoAction.audioPlayerClient)
          .cancellable(id: PlayerId()),

        Effect.timer(id: TimerId(), every: 0.5, on: environment.mainQueue)
          .map {
            .timerUpdated(
              TimeInterval($0.dispatchTime.uptimeNanoseconds - start.dispatchTime.uptimeNanoseconds)
                / TimeInterval(NSEC_PER_SEC)
            )
          }
      )

    case .playing:
      memo.mode = .notPlaying
      return .concatenate(
        .cancel(id: TimerId()),
        environment.audioPlayerClient
          .stop(PlayerId())
          .fireAndForget()
      )
    }

  case let .timerUpdated(time):
    switch memo.mode {
    case .notPlaying:
      break
    case let .playing(progress: progress):
      memo.mode = .playing(progress: time / memo.duration)
    }
    return .none

  case let .titleTextFieldChanged(text):
    memo.title = text
    return .none
  }
}

struct VoiceMemosState: Equatable {
  var alertMessage: String?
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
      state.alertMessage = nil
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
      state.alertMessage = "Voice memo recording failed."
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
        state.alertMessage = "Permission is required to record voice memos."
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
        state.alertMessage = "Permission is required to record voice memos."
        return .none
      }

    case .voiceMemo(index: _, action: .audioPlayerClient(.failure)):
      state.alertMessage = "Voice memo playback failed."
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
                .foregroundColor(.black)
                .frame(width: 74, height: 74)

              Button(action: { viewStore.send(.recordButtonTapped) }) {
                RoundedRectangle(cornerRadius: viewStore.currentRecording != nil ? 4 : 35)
                  .foregroundColor(.red)
                  .padding(viewStore.currentRecording != nil ? 17 : 2)
                  .animation(.spring())
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
                  .colorMultiply(Int(duration).isMultiple(of: 2) ? .red : .black)
                  .animation(.easeInOut(duration: 0.5))
              }
            }
          }
          .padding()
          .animation(Animation.easeInOut(duration: 0.3))
        }
        .alert(
          item: viewStore.binding(
            get: { $0.alertMessage.map(AlertData.init) },
            send: .alertDismissed
          )
        ) { alertMessage in
          Alert(title: Text(alertMessage.message))
        }
        .navigationBarTitle("Voice memos")
      }
      .navigationViewStyle(StackNavigationViewStyle())
    }
  }
}

struct VoiceMemoView: View {
  // NB: We are using an explicit `ObservedObject` for the view store here instead of
  // `WithViewStore` due to a SwiftUI bug where `GeometryReader`s inside `WithViewStore` will
  // not properly update.
  //
  // Feedback filed: https://gist.github.com/mbrandonw/cc5da3d487bcf7c4f21c27019a440d18
  @ObservedObject var viewStore: ViewStore<VoiceMemo, VoiceMemoAction>

  init(store: Store<VoiceMemo, VoiceMemoAction>) {
    self.viewStore = ViewStore(store)
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        if self.viewStore.mode.isPlaying {
          Rectangle()
            .foregroundColor(Color(white: 0.9))
            .frame(width: proxy.size.width * CGFloat(self.viewStore.mode.progress ?? 0))
            .animation(.linear(duration: 0.5))
        }

        HStack {
          TextField(
            "Untitled, \(dateFormatter.string(from: self.viewStore.date))",
            text: self.viewStore.binding(
              get: { $0.title }, send: VoiceMemoAction.titleTextFieldChanged)
          )

          Spacer()

          dateComponentsFormatter.string(from: self.currentTime).map {
            Text($0)
              .font(Font.footnote.monospacedDigit())
              .foregroundColor(.gray)
          }

          Button(action: { self.viewStore.send(.playButtonTapped) }) {
            Image(systemName: self.viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
              .font(Font.system(size: 22))
          }
        }
        .padding([.leading, .trailing])
      }
    }
    .buttonStyle(BorderlessButtonStyle())
    .listRowBackground(self.viewStore.mode.isPlaying ? Color(white: 0.97) : .clear)
    .listRowInsets(EdgeInsets())
  }

  var currentTime: TimeInterval {
    self.viewStore.mode.progress.map { $0 * self.viewStore.duration } ?? self.viewStore.duration
  }
}

private struct AlertData: Identifiable {
  var message: String
  var id: String { self.message }
}

private let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()

private let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()

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
  }
}
