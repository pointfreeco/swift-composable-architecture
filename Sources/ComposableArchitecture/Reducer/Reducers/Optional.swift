extension Optional: Reducer where Wrapped: Reducer {
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
