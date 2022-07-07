import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemo: Equatable, Identifiable {
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
  var audioPlayerClient: AudioPlayerClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let voiceMemoReducer = Reducer<
  VoiceMemo, VoiceMemoAction, VoiceMemoEnvironment
> { memo, action, environment in
  enum PlayID {}

  switch action {
  case .audioPlayerClient:
    memo.mode = .notPlaying
    return .cancel(id: PlayID.self)

  case .delete:
    return .cancel(id: PlayID.self)

  case .playButtonTapped:
    switch memo.mode {
    case .notPlaying:
      memo.mode = .playing(progress: 0)

      return .run { [url = memo.url] send in
        let start = environment.mainRunLoop.now

        async let playAudio: Void = send(
          .audioPlayerClient(TaskResult { try await environment.audioPlayerClient.play(url) })
        )

        for try await tick in environment.mainRunLoop.timer(interval: 0.5) {
          await send(.timerUpdated(tick.date.timeIntervalSince(start.date)))
        }
      }
      .cancellable(id: PlayID.self, cancelInFlight: true)

    case .playing:
      memo.mode = .notPlaying
      return .cancel(id: PlayID.self)
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

struct VoiceMemoView: View {
  let store: Store<VoiceMemo, VoiceMemoAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      let currentTime =
        viewStore.mode.progress.map { $0 * viewStore.duration } ?? viewStore.duration
      HStack {
        TextField(
          "Untitled, \(viewStore.date.formatted(date: .numeric, time: .shortened))",
          text: viewStore.binding(
            get: \.title, send: VoiceMemoAction.titleTextFieldChanged)
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
