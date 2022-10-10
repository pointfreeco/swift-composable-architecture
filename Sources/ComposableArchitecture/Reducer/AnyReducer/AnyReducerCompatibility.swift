extension Reduce {
  @available(
    iOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  public init<Environment>(
    _ reducer: AnyReducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(internal: { state, action in
      reducer.run(&state, action, environment)
    })
  }
}

@available(
  iOS,
  deprecated: 9999.0,
  message:
    """
    'Reducer' has been deprecated in favor of 'ReducerProtocol'.

    See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
    """
)
@available(
  macOS,
  deprecated: 9999.0,
  message:
    """
    'Reducer' has been deprecated in favor of 'ReducerProtocol'.

    See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
    """
)
@available(
  tvOS,
  deprecated: 9999.0,
  message:
    """
    'Reducer' has been deprecated in favor of 'ReducerProtocol'.

    See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
    """
)
@available(
  watchOS,
  deprecated: 9999.0,
  message:
    """
    'Reducer' has been deprecated in favor of 'ReducerProtocol'.

    See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
    """
)
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
  @available(
    iOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    macOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    tvOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
  @available(
    watchOS,
    deprecated: 9999.0,
    message:
      """
      'Reducer' has been deprecated in favor of 'ReducerProtocol'.

      See the migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/reducerprotocol
      """
  )
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
