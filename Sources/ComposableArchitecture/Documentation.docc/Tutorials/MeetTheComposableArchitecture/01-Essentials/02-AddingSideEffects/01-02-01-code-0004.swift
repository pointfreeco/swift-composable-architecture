import ComposableArchitecture

@Reducer
struct CounterFeature {
  @ObservableState
  struct State {
    var count = 0
    var fact: String?
    var isLoading = false
  }
  
  enum Action {
    case decrementButtonTapped
    case factButtonTapped
    case incrementButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
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
}
