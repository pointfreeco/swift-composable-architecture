import ComposableArchitecture
import SwiftUI

@Reducer
struct RecordingMemo {
  struct State: Equatable {
    var date: Date
    var duration: TimeInterval = 0
    var mode: Mode = .recording
    var url: URL

    enum Mode {
      case recording
      case encoding
    }
  }

  enum Action {
    case audioRecorderDidFinish(Result<Bool, Error>)
    case delegate(Delegate)
    case finalRecordingTime(TimeInterval)
    case onTask
    case timerUpdated
    case stopButtonTapped

    @CasePathable
    enum Delegate {
      case didFinish(Result<State, Error>)
    }
  }

  struct Failed: Equatable, Error {}

  @Dependency(\.audioRecorder) var audioRecorder
  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .audioRecorderDidFinish(.success(true)):
        return .send(.delegate(.didFinish(.success(state))))

      case .audioRecorderDidFinish(.success(false)):
        return .send(.delegate(.didFinish(.failure(Failed()))))

      case let .audioRecorderDidFinish(.failure(error)):
        return .send(.delegate(.didFinish(.failure(error))))

      case .delegate:
        return .none

      case let .finalRecordingTime(duration):
        state.duration = duration
        return .none

      case .stopButtonTapped:
        state.mode = .encoding
        return .run { send in
          if let currentTime = await self.audioRecorder.currentTime() {
            await send(.finalRecordingTime(currentTime))
          }
          await self.audioRecorder.stopRecording()
        }

      case .onTask:
        return .run { [url = state.url] send in
          async let startRecording: Void = send(
            .audioRecorderDidFinish(
              Result { try await self.audioRecorder.startRecording(url) }
            )
          )
          for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerUpdated)
          }
          await startRecording
        }

      case .timerUpdated:
        state.duration += 1
        return .none
      }
    }
  }
}

struct RecordingMemoView: View {
  let store: StoreOf<RecordingMemo>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
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

          Button {
            viewStore.send(.stopButtonTapped, animation: .default)
          } label: {
            RoundedRectangle(cornerRadius: 4)
              .foregroundColor(Color(.systemRed))
              .padding(17)
          }
          .frame(width: 70, height: 70)
        }
      }
      .task {
        await viewStore.send(.onTask).finish()
      }
    }
  }
}
