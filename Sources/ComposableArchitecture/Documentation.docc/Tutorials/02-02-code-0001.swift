import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action {
    case decrementButtonTapped
    case factButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return .none

    case .factButtonTapped:
      state.isLoading = true
      return .run { send in
        // ✅ Do async work in here, and send actions
        //    back into the system.
      }

    case .incrementButtonTapped:
      state.count += 1
      return .none
    }
  }
}
