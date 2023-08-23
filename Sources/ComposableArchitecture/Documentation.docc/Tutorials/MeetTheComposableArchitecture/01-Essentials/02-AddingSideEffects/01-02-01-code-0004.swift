import ComposableArchitecture

struct CounterFeature: Reducer {
  struct State: Equatable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case factButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      state.fact = nil
      return .none

    case .factButtonTapped:
      state.fact = nil
      state.isLoading = true
      return .none

    case .incrementButtonTapped:
      state.count += 1
      state.fact = nil
      return .none
    }
  }
}
