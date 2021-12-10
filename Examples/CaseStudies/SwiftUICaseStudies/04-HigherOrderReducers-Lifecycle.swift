import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to trigger effects when a view appears, and cancel effects when a view \
  disappears. This can be helpful for starting up a feature's long living effects, such as timers, \
  location managers, etc. when that feature is first presented.

  To accomplish this we define a higher-order reducer that enhances any reducer with two additional \
  actions, `.onAppear` and `.onDisappear`, and a way to automate running effects when those actions \
  are sent to the store.
  """

extension Reducer {
  public func lifecycle(
    onAppear: @escaping (Environment) -> Effect<Action, Never>,
    onDisappear: @escaping (Environment) -> Effect<Never, Never>
  ) -> Reducer<State?, LifecycleAction<Action>, Environment> {

    return .init { state, lifecycleAction, environment in
      switch lifecycleAction {
      case .onAppear:
        return onAppear(environment).map(LifecycleAction.action)

      case .onDisappear:
        return onDisappear(environment).fireAndForget()

      case let .action(action):
        guard state != nil else { return .none }
        return self.run(&state!, action, environment)
          .map(LifecycleAction.action)
      }
    }
  }
}

public enum LifecycleAction<Action> {
  case onAppear
  case onDisappear
  case action(Action)
}

extension LifecycleAction: Equatable where Action: Equatable {}

struct LifecycleDemoState: Equatable {
  var count: Int?
}

enum LifecycleDemoAction: Equatable {
  case timer(LifecycleAction<TimerAction>)
  case toggleTimerButtonTapped
}

struct LifecycleDemoEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lifecycleDemoReducer:
  Reducer<LifecycleDemoState, LifecycleDemoAction, LifecycleDemoEnvironment> = .combine(
    timerReducer.pullback(
      state: \.count,
      action: /LifecycleDemoAction.timer,
      environment: { TimerEnvironment(mainQueue: $0.mainQueue) }
    ),
    Reducer { state, action, environment in
      switch action {
      case .timer:
        return .none

      case .toggleTimerButtonTapped:
        state.count = state.count == nil ? 0 : nil
        return .none
      }
    }
  )

struct LifecycleDemoView: View {
  let store: Store<LifecycleDemoState, LifecycleDemoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        Button("Toggle Timer") { viewStore.send(.toggleTimerButtonTapped) }

        IfLetStore(
          self.store.scope(state: \.count, action: LifecycleDemoAction.timer),
          then: TimerView.init(store:)
        )

        Spacer()
      }
      .navigationBarTitle("Lifecycle")
    }
  }
}

private struct TimerId: Hashable {}

enum TimerAction {
  case decrementButtonTapped
  case incrementButtonTapped
  case tick
}

struct TimerEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

private let timerReducer = Reducer<Int, TimerAction, TimerEnvironment> {
  state, action, TimerEnvironment in
  switch action {
  case .decrementButtonTapped:
    state -= 1
    return .none

  case .incrementButtonTapped:
    state += 1
    return .none

  case .tick:
    state += 1
    return .none
  }
}
.lifecycle(
  onAppear: {
    Effect.timer(id: TimerId(), every: 1, tolerance: 0, on: $0.mainQueue)
      .map { _ in TimerAction.tick }
  },
  onDisappear: { _ in
    .cancel(id: TimerId())
  }
)

private struct TimerView: View {
  let store: Store<Int, LifecycleAction<TimerAction>>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Section {
        Text("Count: \(viewStore.state)")
          .onAppear { viewStore.send(.onAppear) }
          .onDisappear { viewStore.send(.onDisappear) }

        Button("Decrement") { viewStore.send(.action(.decrementButtonTapped)) }

        Button("Increment") { viewStore.send(.action(.incrementButtonTapped)) }
      }
    }
  }
}

struct Lifecycle_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        LifecycleDemoView(
          store: .init(
            initialState: .init(),
            reducer: lifecycleDemoReducer,
            environment: .init(
              mainQueue: .main
            )
          )
        )
      }
    }
  }
}
