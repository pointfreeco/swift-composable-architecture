extension Reduce {
  public init<Environment>(
    _ reducer: AnyReducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init { state, action in
      reducer.run(&state, action, environment)
    }
  }
}

extension AnyReducer {
  public init<R: ReducerProtocol>(@ReducerBuilderOf<R> _ build: @escaping (Environment) -> R)
  where R.State == State, R.Action == Action {
    self.init { state, action, environment in
      build(environment).reduce(into: &state, action: action)
    }
  }

  public init<R: ReducerProtocol>(_ reducer: R) where R.State == State, R.Action == Action {
    self.init { _ in reducer }
  }
}

extension Store {
  /// Initializes a store from an initial state, a reducer, and an environment.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public convenience init<Environment>(
    initialState: State,
    reducer: AnyReducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      initialState: initialState,
      reducer: Reduce(reducer, environment: environment)
    )
  }
}
