import ComposableArchitecture

struct CounterFeature: Reducer {
  struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .decrementButtonTapped:

    case .incrementButtonTapped:

    }
  }
}
