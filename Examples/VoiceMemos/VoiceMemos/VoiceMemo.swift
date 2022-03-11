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
  case audioPlayerClient(Result<AudioPlayerClient.Action, AudioPlayerClient.Failure>)
  case playButtonTapped
  case delete
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
  struct TimerId: Hashable {}

  switch action {
  case .audioPlayerClient(.success(.didFinishPlaying)), .audioPlayerClient(.failure):
    memo.mode = .notPlaying
    return .cancel(id: TimerId())

  case .delete:
    return .merge(
      environment.audioPlayerClient.stop().fireAndForget(),
      .cancel(id: TimerId())
    )

  case .playButtonTapped:
    switch memo.mode {
    case .notPlaying:
      memo.mode = .playing(progress: 0)

      let start = environment.mainRunLoop.now
      return .merge(
        Effect.timer(id: TimerId(), every: 0.5, on: environment.mainRunLoop)
          .map { .timerUpdated($0.date.timeIntervalSince1970 - start.date.timeIntervalSince1970) },

        environment.audioPlayerClient
          .play(memo.url)
          .catchToEffect(VoiceMemoAction.audioPlayerClient)
      )

    case .playing:
      memo.mode = .notPlaying

      return .concatenate(
        .cancel(id: TimerId()),
        environment.audioPlayerClient.stop().fireAndForget()
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
