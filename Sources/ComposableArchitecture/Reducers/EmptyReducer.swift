public struct EmptyReducer<State, Action>: ReducerProtocol {
  @inlinable
  public init() {}

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    .none
  }
}
