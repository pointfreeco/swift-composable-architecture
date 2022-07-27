public struct EmptyReducer<State, Action>: ReducerProtocol {
  @inlinable
  public init() {}

  @inlinable
  public func reduce(into _: inout State, action _: Action) -> Effect<Action, Never> {
    .none
  }
}
