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
  enum PlayId {}
  enum TimerId {}

  switch action {
  case .audioPlayerClient:
    memo.mode = .notPlaying
    return .cancel(id: TimerId.self)

  case .delete:
    return .cancel(ids: [PlayId.self, TimerId.self])

  case .playButtonTapped:
    switch memo.mode {
    case .notPlaying:
      memo.mode = .playing(progress: 0)

      return .run { @MainActor [url = memo.url] send in
        let start = environment.mainRunLoop.now

        await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask { @MainActor in
            for try await tick in environment.mainRunLoop.timer(interval: 0.5) {
              send(.timerUpdated(tick.date.timeIntervalSince(start.date)))
            }
          }
          group.addTask { @MainActor in
            send(
              await .audioPlayerClient(.init { try await environment.audioPlayerClient.play(url) })
            )
          }
        }
      }
      .cancellable(id: PlayId.self, cancelInFlight: true)

    case .playing:
      memo.mode = .notPlaying
      return .cancel(ids: [PlayId.self, TimerId.self])
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
