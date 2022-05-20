public struct Reduce<State, Action>: ReducerProtocol {
  @usableFromInline
  let reduce: (inout State, Action) -> Effect<Action, Never>

  @inlinable
  public init(_ reduce: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reduce = reduce
  }

  @inlinable
  public init<R: ReducerProtocol>(_ reducer: R)
  where R.State == State, R.Action == Action {
    self.reduce = reducer.reduce
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reduce(&state, action)
  }
}
