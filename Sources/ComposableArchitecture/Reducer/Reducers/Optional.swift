extension Optional: Reducer where Wrapped: Reducer {
  @inlinable
  public func _reduce(
    into state: inout Wrapped.State, action: Wrapped.Action
  ) -> Effect<Wrapped.Action> {
    switch self {
    case .some(let wrapped):
      return wrapped._reduce(into: &state, action: action)
    case .none:
      return .none
    }
  }
}
