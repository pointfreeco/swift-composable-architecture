import ComposableArchitecture
@preconcurrency import SwiftUI  // NB: SwiftUI.Animation is not Sendable yet.

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with \
  extra functionality.

  In this example we introduce a declarative interface for describing long-running effects, \
  inspired by Elm's `subscriptions` API.
  """

extension Reducer {
  static func subscriptions(
    _ subscriptions: @escaping (State, Environment) -> [AnyHashable: Effect<Action, Never>]
  ) -> Self {
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
    guard state.isTimerActive else { return [:] }
    struct TimerID: Hashable {}
    return [
      TimerID(): .run { send in
        for await _ in environment.mainQueue.timer(interval: 1) {
          await send(.timerTicked, animation: .interpolatingSpring(stiffness: 3000, damping: 40))
        }
      }
    ]
  }
)

struct ClockView: View {
  let store: Store<ClockState, ClockAction>

  var body: some View {
    WithViewStore(store) { viewStore in
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
      .navigationTitle("Elm-like subscriptions")
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
