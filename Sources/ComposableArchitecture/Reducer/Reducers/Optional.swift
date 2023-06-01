extension Optional: ReducerProtocol where Wrapped: ReducerProtocol {
  @inlinable
  public func reduce(
    into state: inout Wrapped.State, action: Wrapped.Action
  ) -> EffectTask<Wrapped.Action> {
    switch self {
    case let .some(wrapped):
      return wrapped.reduce(into: &state, action: action)
    case .none:
      return .none
    }
  }
}
