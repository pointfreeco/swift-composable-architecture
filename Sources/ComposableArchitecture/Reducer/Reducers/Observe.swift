//public struct _Observe<Reducers: ReducerProtocol>: ReducerProtocol {
//  @usableFromInline
//  let reducers: (State, Action) -> Reducers
//
//  /// Initializes a reducer that builds a reducer from the current state and action.
//  ///
//  /// - Parameter build: A reducer builder that has access to the current state and action.
//  @inlinable
//  public init<State, Action>(
//    @ReducerBuilder<State, Action> _ build: @escaping (State, Action) -> Reducers
//  ) where Reducers.State == State, Reducers.Action == Action {
//    self.reducers = build
//  }
//
//  @inlinable
//  public func reduce(
//    into state: inout Reducers.State, action: Reducers.Action
//  ) -> EffectTask<Reducers.Action> {
//    self.reducers(state, action).reduce(into: &state, action: action)
//  }
//}
