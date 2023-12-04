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
}
