import ComposableArchitecture

@Reducer
struct CounterFeature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }
  
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
