import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with \
  extra functionality.

  In this example we introduce a declarative interface for describing long-running effects, \
  inspired by Elm's `subscriptions` API.
  """

extension Reducer {
  static func subscriptions(
    _ subscriptions: @escaping (State, Environment) -> [AnyHashable: Effect<Action, Never>]
  ) -> Reducer {
    var activeSubscriptions: [AnyHashable: Effect<Action, Never>] = [:]

    return Reducer { state, _, environment in
      let currentSubscriptions = subscriptions(state, environment)
      defer { activeSubscriptions = currentSubscriptions }
      return .merge(
        Set(activeSubscriptions.keys).union(currentSubscriptions.keys).map { id in
          switch (activeSubscriptions[id], currentSubscriptions[id]) {
          case (.some, .none):
            return .cancel(id: id)
          case let (.none, .some(effect)):
            return effect.cancellable(id: id)
          default:
            return .none
          }
        }
      )
    }
  }
}

struct ClockState: Equatable {
  var isTimerActive = false
  var secondsElapsed = 0
}

enum ClockAction: Equatable {
  case timerTicked
  case toggleTimerButtonTapped
}

struct ClockEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let clockReducer = Reducer<ClockState, ClockAction, ClockEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .timerTicked:
      state.secondsElapsed += 1
      return .none
    case .toggleTimerButtonTapped:
      state.isTimerActive.toggle()
      return .none
    }
  },
  .subscriptions { state, environment in
    struct TimerId: Hashable {}
    guard state.isTimerActive else { return [:] }
    return [
      TimerId():
        Effect
        .timer(
          id: TimerId(),
          every: 1,
          tolerance: .zero,
          on: environment.mainQueue.animation(.interpolatingSpring(stiffness: 3000, damping: 40))
        )
        .map { _ in .timerTicked }
    ]
  }
)

struct ClockView: View {
  let store: Store<ClockState, ClockAction>

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
        .padding(.bottom, 64)

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
      .navigationBarTitle("Elm-like subscriptions")
    }
  }
}

struct Subscriptions_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ClockView(
        store: Store(
          initialState: ClockState(),
          reducer: clockReducer,
          environment: ClockEnvironment(
            mainQueue: .main
          )
        )
      )
    }
  }
}
