import ComposableArchitecture
import SwiftUI

struct RecordingMemoState: Equatable {
  var alert: AlertState<RecordingMemoAction>?
  var date: Date
  var duration: TimeInterval = 0
  var mode: Mode = .recording
  var url: URL

  enum Mode {
    case recording
    case encoding
  }
}

enum RecordingMemoAction: Equatable {
  case alertDismissed
  case audioRecorderDidFinish(TaskResult<Bool>)
  case finalRecordingTime(TimeInterval)
  case task
  case timerUpdated
  case stopButtonTapped
}

struct RecordingMemoEnvironment {
  var audioRecorder: AudioRecorderClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let recordingMemoReducer = Reducer<
  RecordingMemoState,
  RecordingMemoAction,
  RecordingMemoEnvironment
> { state, action, environment in
  enum RecordID {}

  switch action {
  case .alertDismissed:
    state.alert = nil
    return .none
    
  case .audioRecorderDidFinish(.success(true)):
    guard state.mode == .encoding
    else {
      assertionFailure()
      return .none
    }
    return .cancel(id: RecordID.self)

  case
      .audioRecorderDidFinish(.success(false)),
      .audioRecorderDidFinish(.failure):
    state.alert = AlertState(title: TextState("Voice memo recording failed."))
    return .cancel(id: RecordID.self)

  case .timerUpdated:
    state.duration += 1
    return .none

  case let .finalRecordingTime(duration):
    state.duration = duration
    return .none

  case .task:
    return .run { [url = state.url] send in
      async let startRecording: Void = await send(
        .audioRecorderDidFinish(
          TaskResult { try await environment.audioRecorder.startRecording(url) }
        )
      )

      for await _ in environment.mainRunLoop.timer(interval: .seconds(1)) {
        await send(.timerUpdated)
      }
    }
    .cancellable(id: RecordID.self, cancelInFlight: true)

  case .stopButtonTapped:
    state.mode = .encoding
    return .run { send in
      if let currentTime = await environment.audioRecorder.currentTime() {
        await send(.finalRecordingTime(currentTime))
      }
      await environment.audioRecorder.stopRecording()
    }
  }
}

struct RecordingMemoView: View {
  let store: Store<RecordingMemoState, RecordingMemoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(spacing: 12) {
        Text("Recording")
          .font(.title)
          .colorMultiply(Color(Int(viewStore.duration).isMultiple(of: 2) ? .systemRed : .label))
          .animation(.easeInOut(duration: 0.5), value: viewStore.duration)

        if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
          Text(formattedDuration)
            .font(.body.monospacedDigit().bold())
            .foregroundColor(.black)
        }

        ZStack {
          Circle()
            .foregroundColor(Color(.label))
            .frame(width: 74, height: 74)

          Button(action: { viewStore.send(.stopButtonTapped, animation: .default) }) {
            RoundedRectangle(cornerRadius: 4)
              .foregroundColor(Color(.systemRed))
              .padding(17)
          }
          .frame(width: 70, height: 70)
        }
      }
      .alert(
        self.store.scope(state: \.alert),
        dismiss: .alertDismissed
      )
      .task {
        await viewStore.send(.task).finish()
      }
    }
  }
}
