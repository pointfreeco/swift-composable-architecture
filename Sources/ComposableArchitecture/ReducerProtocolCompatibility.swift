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

extension TestStore {
  /// Initializes a test store from an initial state, a reducer, and an initial environment.
  ///
  /// - Parameters:
  ///   - initialState: The state to start the test from.
  ///   - reducer: A reducer.
  ///   - environment: The environment to start the test from.
  public convenience init(
    initialState: LocalState,
    reducer: ComposableArchitecture.Reducer<LocalState, LocalAction, Environment>,
    environment: Environment,
    file: StaticString = #file,
    line: UInt = #line
  )
  where
    Reducer == Reduce<LocalState, LocalAction>
  {
    let environment = Box(wrappedValue: environment)
    let reducer = TestReducer(
      Reduce(
        reducer.pullback(state: \.self, action: .self, environment: { $0.wrappedValue }),
        environment: environment
      ),
      initialState: initialState
    )
    self.init(
      _environment: environment,
      file: file,
      fromLocalAction: { $0 },
      line: line,
      reducer: reducer,
      store: Store(initialState: initialState, reducer: reducer),
      toLocalState: { $0 }
    )
  }
}
