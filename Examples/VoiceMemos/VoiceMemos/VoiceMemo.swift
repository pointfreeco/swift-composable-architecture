import ComposableArchitecture
import Foundation
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
    case audioPlayerClient(Result<AudioPlayerClient.Action, AudioPlayerClient.Failure>)
    case playButtonTapped
    case delete
    case timerUpdated(TimeInterval)
    case titleTextFieldChanged(String)
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.mainRunLoop) var mainRunLoop

  func reduce(into memo: inout State, action: Action) -> Effect<Action, Never> {
    enum TimerId {}

    switch action {
    case .audioPlayerClient(.success(.didFinishPlaying)), .audioPlayerClient(.failure):
      memo.mode = .notPlaying
      return .cancel(id: TimerId.self)

    case .delete:
      return .merge(
        self.audioPlayer.stop().fireAndForget(),
        .cancel(id: TimerId.self)
      )

    case .playButtonTapped:
      switch memo.mode {
      case .notPlaying:
        memo.mode = .playing(progress: 0)

        let start = self.mainRunLoop.now
        return .merge(
          Effect.timer(id: TimerId.self, every: 0.5, on: self.mainRunLoop).map {
            .timerUpdated($0.date.timeIntervalSince1970 - start.date.timeIntervalSince1970)
          },

          self.audioPlayer
            .play(memo.url)
            .catchToEffect(Action.audioPlayerClient)
        )

      case .playing:
        memo.mode = .notPlaying

        return .concatenate(
          .cancel(id: TimerId.self),
          self.audioPlayer.stop().fireAndForget()
        )
      }

    case let .timerUpdated(time):
      switch memo.mode {
      case .notPlaying:
        break
      case .playing:
        memo.mode = .playing(progress: time / memo.duration)
      }
      return .none

    case let .titleTextFieldChanged(text):
      memo.title = text
      return .none
    }
  }
}

struct VoiceMemoView: View {
  let store: StoreOf<VoiceMemo>

  var body: some View {
    WithViewStore(store) { viewStore in
      let currentTime =
        viewStore.mode.progress.map { $0 * viewStore.duration } ?? viewStore.duration
      HStack {
        TextField(
          "Untitled, \(viewStore.date.formatted(date: .numeric, time: .shortened))",
          text: viewStore.binding(
            get: \.title, send: VoiceMemo.Action.titleTextFieldChanged)
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
