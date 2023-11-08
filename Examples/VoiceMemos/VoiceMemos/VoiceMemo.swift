import ComposableArchitecture
import SwiftUI

@Reducer
struct VoiceMemo {
  struct State: Equatable, Identifiable {
    var date: Date
    var duration: TimeInterval
    var mode = Mode.notPlaying
    var title = ""
    var url: URL

    var id: URL { self.url }

    @CasePathable
    @dynamicMemberLookup
    enum Mode: Equatable {
      case notPlaying
      case playing(progress: Double)
    }
  }

  enum Action {
    case audioPlayerClient(Result<Bool, Error>)
    case delegate(Delegate)
    case playButtonTapped
    case timerUpdated(TimeInterval)
    case titleTextFieldChanged(String)

    @CasePathable
    enum Delegate {
      case playbackStarted
      case playbackFailed
    }
  }

  @Dependency(\.audioPlayer) var audioPlayer
  @Dependency(\.continuousClock) var clock
  private enum CancelID { case play }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .audioPlayerClient(.failure):
        state.mode = .notPlaying
        return .merge(
          .cancel(id: CancelID.play),
          .send(.delegate(.playbackFailed))
        )

      case .audioPlayerClient:
        state.mode = .notPlaying
        return .cancel(id: CancelID.play)

      case .delegate:
        return .none

      case .playButtonTapped:
        switch state.mode {
        case .notPlaying:
          state.mode = .playing(progress: 0)

          return .run { [url = state.url] send in
            await send(.delegate(.playbackStarted))

            async let playAudio: Void = send(
              .audioPlayerClient(Result { try await self.audioPlayer.play(url) })
            )

            var start: TimeInterval = 0
            for await _ in self.clock.timer(interval: .milliseconds(500)) {
              start += 0.5
              await send(.timerUpdated(start))
            }

            await playAudio
          }
          .cancellable(id: CancelID.play, cancelInFlight: true)

        case .playing:
          state.mode = .notPlaying
          return .cancel(id: CancelID.play)
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
}

struct VoiceMemoView: View {
  let store: StoreOf<VoiceMemo>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      let currentTime =
        viewStore.mode.playing.map { $0 * viewStore.duration } ?? viewStore.duration
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

        Button {
          viewStore.send(.playButtonTapped)
        } label: {
          Image(systemName: viewStore.mode.is(\.playing) ? "stop.circle" : "play.circle")
            .font(.system(size: 22))
        }
      }
      .buttonStyle(.borderless)
      .frame(maxHeight: .infinity, alignment: .center)
      .padding(.horizontal)
      .listRowBackground(viewStore.mode.is(\.playing) ? Color(.systemGray6) : .clear)
      .listRowInsets(EdgeInsets())
      .background(
        Color(.systemGray5)
          .frame(maxWidth: viewStore.mode.is(\.playing) ? .infinity : 0)
          .animation(
            viewStore.mode.is(\.playing) ? .linear(duration: viewStore.duration) : nil,
            value: viewStore.mode.is(\.playing)
          ),
        alignment: .leading
      )
    }
  }
}
