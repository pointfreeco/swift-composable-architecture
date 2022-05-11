public struct Reduce<State, Action>: ReducerProtocol {
  @usableFromInline
  let reduce: (inout State, Action) -> Effect<Action, Never>

  @inlinable
  public init(_ reduce: @escaping (inout State, Action) -> Effect<Action, Never>) {
    self.reduce = reduce
  }

  @inlinable
  public init<R: ReducerProtocol<State, Action>>(_ reducer: R) {
    self.reduce = reducer.reduce
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    self.reduce(&state, action)
  }
}
