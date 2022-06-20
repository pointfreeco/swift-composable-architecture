extension Reducer {
  public init<R: ReducerProtocol>(_ reducer: R) where R.State == State, R.Action == Action {
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
  /// Initializes a store from an initial state, a reducer, and an environment.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      initialState: initialState,
      reducer: Reduce(reducer, environment: environment)
    )
  }

  /// Initializes a store from an initial state, a reducer, and an environment, and the main thread
  /// check is disabled for all interactions with this store.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the application in.
  ///   - reducer: The reducer that powers the business logic of the application.
  ///   - environment: The environment of dependencies for the application.
  public static func unchecked<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) -> Self {
    self.init(
      initialState: initialState,
      reducer: Reduce(reducer, environment: environment),
      mainThreadChecksEnabled: false
    )
  }
}
