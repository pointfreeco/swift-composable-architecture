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

struct Timers: ReducerProtocol {
  struct State: Equatable {
    var isTimerActive = false
    var secondsElapsed = 0
  }

  enum Action {
    case timerTicked
    case toggleTimerButtonTapped
  }

  @Dependency(\.mainQueue) var mainQueue

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
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
          on: self.mainQueue.animation(.interpolatingSpring(stiffness: 3000, damping: 40))
        )
        .map { _ in .timerTicked }
        : .cancel(id: TimerId.self)
    }
  }
}

// MARK: - Timer feature view

struct TimersView: View {
  let store: StoreOf<Timers>

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
          initialState: .init(),
          reducer: Timers()
        )
      )
    }
  }
}
