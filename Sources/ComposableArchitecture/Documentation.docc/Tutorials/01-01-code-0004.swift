import ComposableArchitecture

struct CounterFeature: Reducer {
  struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
