import ComposableArchitecture

struct CounterFeature: Reducer {
  struct State: Equatable {
    var count = 0
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
