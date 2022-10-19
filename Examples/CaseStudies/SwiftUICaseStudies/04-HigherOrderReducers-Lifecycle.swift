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

struct LifecycleReducer<Wrapped: ReducerProtocol>: ReducerProtocol {
  enum Action {
    case onAppear
    case onDisappear
    case wrapped(Wrapped.Action)
  }

  let wrapped: Wrapped
  let onAppear: EffectTask<Wrapped.Action>
  let onDisappear: EffectTask<Never>

  var body: some ReducerProtocol<Wrapped.State?, Action> {
    Reduce { state, lifecycleAction in
      switch lifecycleAction {
      case .onAppear:
        return onAppear.map(Action.wrapped)

      case .onDisappear:
        return onDisappear.fireAndForget()

      case .wrapped:
        return .none
      }
    }
    .ifLet(\.self, action: /Action.wrapped) {
      self.wrapped
    }
  }
}

extension LifecycleReducer.Action: Equatable where Wrapped.Action: Equatable {}

extension ReducerProtocol {
  func lifecycle(
    onAppear: EffectTask<Action>,
    onDisappear: EffectTask<Never> = .none
  ) -> LifecycleReducer<Self> {
    LifecycleReducer(wrapped: self, onAppear: onAppear, onDisappear: onDisappear)
  }
}

// MARK: - Feature domain

struct LifecycleDemo: ReducerProtocol {
  struct State: Equatable {
    var count: Int?
  }

  enum Action: Equatable {
    case timer(LifecycleReducer<Timer>.Action)
    case toggleTimerButtonTapped
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .timer:
        return .none

      case .toggleTimerButtonTapped:
        state.count = state.count == nil ? 0 : nil
        return .none
      }
    }

    Scope(state: \.count, action: /Action.timer) {
      Timer()
        .lifecycle(
          onAppear: .run { send in
            for await _ in self.clock.timer(interval: .seconds(1)) {
              await send(.tick)
            }
          }
          .cancellable(id: CancelID.self),
          onDisappear: .cancel(id: CancelID.self)
        )
    }
  }
}

// MARK: - Feature view

struct LifecycleDemoView: View {
  let store: StoreOf<LifecycleDemo>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Button("Toggle Timer") { viewStore.send(.toggleTimerButtonTapped) }

        IfLetStore(self.store.scope(state: \.count, action: LifecycleDemo.Action.timer)) {
          TimerView(store: $0)
        }
      }
    }
    .navigationTitle("Lifecycle")
  }
}

struct Timer: ReducerProtocol {
  typealias State = Int

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
    case tick
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
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
  }
}

private struct TimerView: View {
  let store: Store<Int, LifecycleReducer<Timer>.Action>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Section {
        Text("Count: \(viewStore.state)")
          .onAppear { viewStore.send(.onAppear) }
          .onDisappear { viewStore.send(.onDisappear) }

        Button("Decrement") { viewStore.send(.wrapped(.decrementButtonTapped)) }

        Button("Increment") { viewStore.send(.wrapped(.incrementButtonTapped)) }
      }
    }
  }
}

// MARK: - SwiftUI previews

struct Lifecycle_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        LifecycleDemoView(
          store: Store(
            initialState: LifecycleDemo.State(),
            reducer: LifecycleDemo()
          )
        )
      }
    }
  }
}
