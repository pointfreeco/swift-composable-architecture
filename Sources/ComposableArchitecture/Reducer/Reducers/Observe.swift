public struct _Observe<Reducers: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let reducers: (State, Action) -> Reducers

  /// Initializes a reducer that builds a reducer from the current state and action.
  ///
  /// - Parameter build: A reducer builder that has access to the current state and action.
  @inlinable
  public init(
    @ReducerBuilderOf<Reducers> _ build: @escaping (Reducers.State, Reducers.Action) -> Reducers
  ) where Reducers.State == State, Reducers.Action == Action {
    self.init(internal: build)
  }

  @_disfavoredOverload
  @usableFromInline
  init(
    internal reducers: @escaping (Reducers.State, Reducers.Action) -> Reducers
  ) {
    self.reducers = reducers
  }

  @inlinable
  public func reduce(
    into state: inout Reducers.State, action: Reducers.Action
  ) -> Effect<Reducers.Action, Never> {
    self.reducers(state, action).reduce(into: &state, action: action)
  }
}
