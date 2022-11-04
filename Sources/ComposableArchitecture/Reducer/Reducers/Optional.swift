extension Optional: ReducerProtocol where Wrapped: ReducerProtocol {
  #if swift(<5.7)
    public typealias State = Wrapped.State
    public typealias Action = Wrapped.Action
    public typealias _Body = Never
  #endif

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
