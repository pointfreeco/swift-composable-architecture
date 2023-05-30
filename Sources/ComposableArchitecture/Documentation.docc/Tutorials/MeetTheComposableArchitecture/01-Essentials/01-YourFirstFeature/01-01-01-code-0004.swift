import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
