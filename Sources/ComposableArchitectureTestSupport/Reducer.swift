import ComposableArchitecture

extension Reducer {
  public func callAsFunction(
    _ state: State,
    _ action: Action,
    _ environment: Environment
  ) -> (State, Effect<Action, Never>) {
    var state = state
    let effects = self.callAsFunction(&state, action, environment)
    return (state, effects)
  }
}

extension Reducer where Environment == Void {
  public func callAsFunction(
    _ state: State,
    _ action: Action
  ) -> State {
    var state = state
    _ = self.callAsFunction(&state, action)
    return state
  }
}
