import ComposableArchitecture
import SwiftUI

struct VoiceMemo: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var date: Date
    var duration: TimeInterval
    var mode = Mode.notPlaying
    var title = ""
    var url: URL

    var id: URL { self.url }

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

  enum Action: Equatable {
    case audioPlayerClient(TaskResult<Bool>)
    case delete
    case playButtonTapped
    case timerUpdated(TimeInterval)
    case titleTextFieldChanged(String)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  private enum PlayID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .audioPlayerClient:
      state.mode = .notPlaying
      return .cancel(id: PlayID.self)

    case .delete:
      return .cancel(id: PlayID.self)

    case .playButtonTapped:
      switch state.mode {
      case .notPlaying:
        state.mode = .playing(progress: 0)

        return .run { [url = state.url] send in
          async let playAudio: Void = send(
            .audioPlayerClient(TaskResult { try await self.audioPlayer.play(url) })
          )

          var start: TimeInterval = 0
          for await _ in self.clock.timer(interval: .milliseconds(500)) {
            start += 0.5
            await send(.timerUpdated(start))
          }

          await playAudio
        }
        .cancellable(id: PlayID.self, cancelInFlight: true)

      case .playing:
        state.mode = .notPlaying
        return .cancel(id: PlayID.self)
      }

    case let .timerUpdated(time):
      switch state.mode {
      case .notPlaying:
        break
      case .playing:
        state.mode = .playing(progress: time / state.duration)
      }
      return .none

    case let .titleTextFieldChanged(text):
      state.title = text
      return .none
    }
  }
}

struct VoiceMemoView: View {
  let store: StoreOf<VoiceMemo>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      let currentTime =
        viewStore.mode.progress.map { $0 * viewStore.duration } ?? viewStore.duration
      HStack {
        TextField(
          "Untitled, \(viewStore.date.formatted(date: .numeric, time: .shortened))",
          text: viewStore.binding(get: \.title, send: { .titleTextFieldChanged($0) })
        )

        Spacer()

        dateComponentsFormatter.string(from: currentTime).map {
          Text($0)
            .font(.footnote.monospacedDigit())
            .foregroundColor(Color(.systemGray))
        }

        Button(action: { viewStore.send(.playButtonTapped) }) {
          Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
            .font(.system(size: 22))
        }
      }
      .buttonStyle(.borderless)
      .frame(maxHeight: .infinity, alignment: .center)
      .padding(.horizontal)
      .listRowBackground(viewStore.mode.isPlaying ? Color(.systemGray6) : .clear)
      .listRowInsets(EdgeInsets())
      .background(
        Color(.systemGray5)
          .frame(maxWidth: viewStore.mode.isPlaying ? .infinity : 0)
          .animation(
            viewStore.mode.isPlaying ? .linear(duration: viewStore.duration) : nil,
            value: viewStore.mode.isPlaying
          ),
        alignment: .leading
      )
    }
  }
}
