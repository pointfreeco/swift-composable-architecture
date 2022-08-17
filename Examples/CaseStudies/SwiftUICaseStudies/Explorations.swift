import ComposableArchitecture

enum Feature {
  struct State {
  }
  enum Action {
    case buttonTapped
    case otherButtonTapped

    case sharedButtonLogic
  }
  struct Environment {
  }
  static let reducer = Reducer<
    State,
    Action,
    Environment
  > { state, action, environment in
    switch action {
    case .buttonTapped:
      // Additional logic
      //return sharedButtonTapLogic(state: &state, environment: environment)
      //return state.sharedButtonTapLogic(environment: environment)
      return Effect(value: .sharedButtonLogic)
    case .otherButtonTapped:
      // Additional logic
      //return sharedButtonTapLogic(state: &state, environment: environment)
      //return state.sharedButtonTapLogic(environment: environment)
      return Effect(value: .sharedButtonLogic)

    case .sharedButtonLogic:
      // Do shared logic
      return .none
    }
  }

  private static func sharedButtonTapLogic(
    state: inout State,
    environment: Environment
  ) -> Effect<Action, Never> {
    .none
  }
}

extension Feature.State {
  fileprivate mutating func sharedButtonTapLogic(
    environment: Feature.Environment
  ) -> Effect<Feature.Action, Never> {
    .none
  }
}
