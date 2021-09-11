extension _Reducer {
  @inlinable
  public func combined<Other>(with other: Other) -> Reducers.Combined<Self, Other>
  where
    Other: _Reducer,
    Other.State == Self.State,
    Other.Action == Self.Action
  {
    .init(self, other)
  }
}

extension Reducers {
  public struct Combined<Reducer1, Reducer2>: _Reducer
  where
    Reducer1: _Reducer,
    Reducer2: _Reducer,
    Reducer1.State == Reducer2.State,
    Reducer1.Action == Reducer2.Action
  {
    public let reducer1: Reducer1
    public let reducer2: Reducer2

    @inlinable
    public init(_ reducer1: Reducer1, _ reducer2: Reducer2) {
      self.reducer1 = reducer1
      self.reducer2 = reducer2
    }

    @inlinable
    public func reduce(into state: inout Reducer1.State, action: Reducer1.Action)
    -> Effect<Reducer1.Action, Never> {
      .merge(
        self.reducer1.reduce(into: &state, action: action),
        self.reducer2.reduce(into: &state, action: action)
      )
    }
  }
}
