extension Reducer where Environment == Void {
  public init<R: ReducerProtocol<State, Action>>(_ reducer: R) {
    self.init { state, action, _ in reducer.reduce(into: &state, action: action) }
  }
}

extension Reduce {
  public init<Environment>(
    _ reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init { state, action in
      reducer.run(&state, action, environment)
    }
  }
}

extension Store {
  // TODO: Make this the default convenience initializer and have the 'Reducer' one call to it
  public convenience init<R: ReducerProtocol<State, Action>>(
    initialState: State,
    reducer: R
  ) {
    self.init(
      initialState: initialState,
      reducer: .init(reducer),
      environment: ()
    )
  }
}
