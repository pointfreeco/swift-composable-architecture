import ComposableArchitecture

struct CounterFeature: ReducerProtocol {
  struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .decrementButtonTapped:

    case .incrementButtonTapped:

    }
  }
}
