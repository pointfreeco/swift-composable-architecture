import ComposableArchitecture

struct CounterFeature: Reducer {
  struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:

      case .incrementButtonTapped:

      }
    }
  }
}
