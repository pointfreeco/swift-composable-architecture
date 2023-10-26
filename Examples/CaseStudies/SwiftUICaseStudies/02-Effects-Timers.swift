import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to work with timers in the Composable Architecture.

  It makes use of the `.timer` method on clocks, which is a helper provided by the Swift Clocks \
  library included with this library. The helper provides an `AsyncSequence`-friendly API for \
  dealing with times in asynchronous code.
  """

// MARK: - Feature domain

@Reducer
struct Timers {
  struct State: Equatable {
    var isTimerActive = false
    var secondsElapsed = 0
  }

  enum Action {
    case onDisappear
    case timerTicked
    case toggleTimerButtonTapped
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case timer }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .onDisappear:
        return .cancel(id: CancelID.timer)

      case .timerTicked:
        state.secondsElapsed += 1
        return .none

      case .toggleTimerButtonTapped:
        state.isTimerActive.toggle()
        return .run { [isTimerActive = state.isTimerActive] send in
          guard isTimerActive else { return }
          for await _ in self.clock.timer(interval: .seconds(1)) {
            await send(.timerTicked, animation: .interpolatingSpring(stiffness: 3000, damping: 40))
          }
        }
        .cancellable(id: CancelID.timer, cancelInFlight: true)
      }
    }
  }
}

// MARK: - Feature view

struct TimersView: View {
  @State var store = Store(initialState: Timers.State()) {
    Timers()
  }

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        AboutView(readMe: readMe)

        ZStack {
          Circle()
            .fill(
              AngularGradient(
                gradient: Gradient(
                  colors: [
                    .blue.opacity(0.3),
                    .blue,
                    .blue,
                    .green,
                    .green,
                    .yellow,
                    .yellow,
                    .red,
                    .red,
                    .purple,
                    .purple,
                    .purple.opacity(0.3),
                  ]
                ),
                center: .center
              )
            )
            .rotationEffect(.degrees(-90))
          GeometryReader { proxy in
            Path { path in
              path.move(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2))
              path.addLine(to: CGPoint(x: proxy.size.width / 2, y: 0))
            }
            .stroke(.primary, lineWidth: 3)
            .rotationEffect(.degrees(Double(viewStore.secondsElapsed) * 360 / 60))
          }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)

        Button {
          viewStore.send(.toggleTimerButtonTapped)
        } label: {
          Text(viewStore.isTimerActive ? "Stop" : "Start")
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .tint(viewStore.isTimerActive ? Color.red : .accentColor)
        .buttonStyle(.borderedProminent)
      }
      .navigationTitle("Timers")
      .onDisappear {
        viewStore.send(.onDisappear)
      }
    }
  }
}

// MARK: - SwiftUI previews

struct TimersView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TimersView(
        store: Store(initialState: Timers.State()) {
          Timers()
        }
      )
    }
  }
}
