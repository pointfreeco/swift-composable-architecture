import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemoState: Equatable, Identifiable {
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

enum VoiceMemoAction: Equatable {
  case audioPlayerClient(TaskResult<Bool>)
  case delete
  case playButtonTapped
  case timerUpdated(TimeInterval)
  case titleTextFieldChanged(String)
}

struct VoiceMemoEnvironment {
  var audioPlayer: AudioPlayerClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let voiceMemoReducer = Reducer<
  VoiceMemoState,
  VoiceMemoAction,
  VoiceMemoEnvironment
> { state, action, environment in
  enum PlayID {}

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
        let start = environment.mainRunLoop.now

        async let playAudio: Void = send(
          .audioPlayerClient(TaskResult { try await environment.audioPlayer.play(url) })
        )

        for try await tick in environment.mainRunLoop.timer(interval: 0.5) {
          await send(.timerUpdated(tick.date.timeIntervalSince(start.date)))
        }
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
    case let .playing(progress: progress):
      state.mode = .playing(progress: time / state.duration)
    }
    return .none

  case let .titleTextFieldChanged(text):
    state.title = text
    return .none
  }
}

struct VoiceMemoView: View {
  let store: Store<VoiceMemoState, VoiceMemoAction>

  var body: some View {
    WithViewStore(store) { viewStore in
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
