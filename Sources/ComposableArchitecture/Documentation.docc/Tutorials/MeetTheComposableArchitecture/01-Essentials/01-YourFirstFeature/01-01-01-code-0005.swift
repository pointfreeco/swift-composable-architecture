import ComposableArchitecture

@Reducer
struct CounterFeature {
  @ObservableState
  struct State {
    var count = 0
  }
  
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
      case .decrementButtonTapped:
        
      case .incrementButtonTapped:
        
      }
    }
  }
}
