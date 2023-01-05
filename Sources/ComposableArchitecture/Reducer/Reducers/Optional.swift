extension Optional: Reducer where Wrapped: Reducer {
  #if swift(<5.7)
    public typealias State = Wrapped.State
    public typealias Action = Wrapped.Action
    public typealias _Body = Never
  #endif

  @inlinable
  public func reduce(
    into state: inout Wrapped.State, action: Wrapped.Action
  ) -> Effect<Wrapped.Action> {
    switch self {
    case let .some(wrapped):
      return wrapped.reduce(into: &state, action: action)
    case .none:
      return .none
    }
  }
}
