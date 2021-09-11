extension _Reducer {
  @inlinable
  public func eraseToAnyReducer() -> AnyReducer<State, Action> {
    .init(self.reduce(into:action:))
  }
}

public struct AnyReducer<State, Action>: _Reducer {
  public let reducer: (inout State, Action) -> Effect<Action, Never>

  @inlinable
  public init(_ reducer: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reducer = reducer
  }

  @inlinable
  public init<R>(_ reducer: R)
  where
    R: _Reducer,
    R.State == State,
    R.Action == Action
  {
    self.reducer = reducer.reduce(into:action:)
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reducer(&state, action)
  }
}
