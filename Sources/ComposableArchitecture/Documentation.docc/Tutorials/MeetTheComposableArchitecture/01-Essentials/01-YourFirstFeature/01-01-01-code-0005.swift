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

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:

      case .incrementButtonTapped:

      }
    }
  }
}
