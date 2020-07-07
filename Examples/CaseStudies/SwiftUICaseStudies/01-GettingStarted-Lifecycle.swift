import ComposableArchitecture
import SwiftUI

private let readMe = """
  TODO
  """

struct LifecyleDemoState: Equatable {
  var count: Int?
}

enum LifecyleDemoAction: Equatable {
  case timer(LifecycleAction<TimerAction>)
  case toggleTimerButtonTapped
}

struct LifecycleDemoEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lifecycleDemoReducer: Reducer<LifecyleDemoState, LifecyleDemoAction, LifecycleDemoEnvironment>
  = .combine(
    timerReducer.pullback(
      state: \.count,
      action: /LifecyleDemoAction.timer,
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
  let store: Store<LifecyleDemoState, LifecyleDemoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        Button("Toggle Timer") { viewStore.send(.toggleTimerButtonTapped) }

        IfLetStore(
          self.store.scope(state: \.count, action: LifecyleDemoAction.timer),
          then: TimerView.init(store:)
        )
      }
    }
  }
}

private struct TimerId: Hashable {}

enum TimerAction {
  case tick
}

struct TimerEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

private let timerReducer = Reducer<Int, TimerAction, TimerEnvironment> { state, action, TimerEnvironment in
  switch action {
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
  })

private struct TimerView: View {
  let store: Store<Int, LifecycleAction<TimerAction>>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Text("Count: \(viewStore.state)")
        .onAppear { viewStore.send(.onAppear) }
        .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}

struct Lifecycle_Previews: PreviewProvider {
  static var previews: some View {
    LifecycleDemoView(
      store: .init(
        initialState: .init(),
        reducer: lifecycleDemoReducer,
        environment: .init(
          mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        )
      )
    )
  }
}
