import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to work with timers in the Composable Architecture.

  Although the Combine framework comes with a `Timer.publisher` API, and it is possible to use \
  that API in the Composable Architecture, it is not easy to test. That is why we have provided an \
  `Effect.timer` API that works with schedulers and can be tested.
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

  enum TimerId {}

  switch action {
  case .timerTicked:
    state.secondsElapsed += 1
    return .none

  case .toggleTimerButtonTapped:
    state.isTimerActive.toggle()
    return state.isTimerActive
      ? Effect.timer(
        id: TimerId.self,
        every: 1,
        tolerance: .zero,
        on: environment.mainQueue.animation(.interpolatingSpring(stiffness: 3000, damping: 40))
      )
      .map { _ in TimersAction.timerTicked }
      : .cancel(id: TimerId.self)
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
            .foregroundStyle(
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
            Capsule()
              .frame(width: 3, height: proxy.size.height / 2)
              .position(x: proxy.size.width/2, y: proxy.size.height / 2)
              .offset(y: -proxy.size.height / 4)
              .rotationEffect(.degrees(Double(viewStore.secondsElapsed) * 360 / 60))
          }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: 280)
        .padding(.vertical, 16)

        Button {
          viewStore.send(.toggleTimerButtonTapped)
        } label: {
          Text(viewStore.isTimerActive ? "Stop" : "Start")
            .padding(8)
        }
        .tint(viewStore.isTimerActive ? Color.red : .accentColor)
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .padding()
      .navigationTitle("Timers")
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
