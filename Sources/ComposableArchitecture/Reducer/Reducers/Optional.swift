extension Optional: Reducer where Wrapped: Reducer {
  @inlinable
  public func reduce(
    into state: inout Wrapped.State, action: Wrapped.Action
  ) -> EffectOf<Wrapped> {
    switch self {
    case .some(let wrapped):
      return wrapped.reduce(into: &state, action: action)
    case .none:
      return .none
    }
  }
}
