extension _Reducer {
  // TODO: Is this usable?
  @inlinable
  public static var empty: Reducers.Empty<State, Action> {
    .init()
  }
}

extension Reducers {
  public struct Empty<State, Action>: _Reducer {
    @inlinable
    public init() {}

    @inlinable
    @inline(__always)
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      return .none
    }
  }
}

