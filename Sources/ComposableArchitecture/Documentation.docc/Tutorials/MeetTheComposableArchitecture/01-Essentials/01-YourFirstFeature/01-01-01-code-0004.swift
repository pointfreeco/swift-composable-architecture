import ComposableArchitecture

@Reducer
struct CounterFeature {
  struct State {
    var count = 0
  }
  
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
