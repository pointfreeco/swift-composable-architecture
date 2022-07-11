import Combine
import ComposableArchitecture
@preconcurrency import SwiftUI  // NB: SwiftUI.Animation is not Sendable yet.

private let readMe = """
  This application demonstrates how to work with timers in the Composable Architecture.
  """

// MARK: - Timer feature domain

struct TimersState: Equatable {
  var isTimerActive = false
  var secondsElapsed = 0
}

enum TimersAction {
  case timerTicked
  case toggleTimerButtonTapped
}

struct TimersEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let timersReducer = Reducer<TimersState, TimersAction, TimersEnvironment> {
  state, action, environment in

  enum TimerID {}

  switch action {
  case .timerTicked:
    state.secondsElapsed += 1
    return .none

  case .toggleTimerButtonTapped:
    state.isTimerActive.toggle()
    return .run { [isTimerActive = state.isTimerActive] send in
      guard isTimerActive else { return }
      for await _ in environment.mainQueue.timer(interval: 1) {
        await send(.timerTicked, animation: .interpolatingSpring(stiffness: 3000, damping: 40))
      }
    }
    .cancellable(id: TimerID.self, cancelInFlight: true)
  }
}

// MARK: - Timer feature view

struct TimersView: View {
  let store: Store<TimersState, TimersAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      VStack {
        Text(template: readMe, .body)

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
            .stroke(Color.black, lineWidth: 3)
            .rotationEffect(.degrees(Double(viewStore.secondsElapsed) * 360 / 60))
          }
        }
        .frame(width: 280, height: 280)
        .padding(.bottom, 16)

        Button(action: { viewStore.send(.toggleTimerButtonTapped) }) {
          HStack {
            Text(viewStore.isTimerActive ? "Stop" : "Start")
          }
          .foregroundColor(.white)
          .padding()
          .background(viewStore.isTimerActive ? Color.red : .blue)
          .cornerRadius(16)
        }

        Spacer()
      }
      .padding()
      .navigationBarTitle("Timers")
    }
  }
}

// MARK: - SwiftUI previews

struct TimersView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TimersView(
        store: Store(
          initialState: TimersState(),
          reducer: timersReducer,
          environment: TimersEnvironment(
            mainQueue: .main
          )
        )
      )
    }
  }
}
