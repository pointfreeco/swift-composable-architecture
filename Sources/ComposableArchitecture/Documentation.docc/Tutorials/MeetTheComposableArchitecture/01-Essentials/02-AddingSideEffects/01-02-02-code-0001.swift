import ComposableArchitecture

struct CounterFeature: Reducer {
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

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        state.fact = nil
        return .none
        
      case .factButtonTapped:
        state.fact = nil
        state.isLoading = true
        return .run { send in
          // ✅ Do async work in here, and send actions back into the system.
        }
        
      case .incrementButtonTapped:
        state.count += 1
        state.fact = nil
        return .none
      }
    }
  }
}
