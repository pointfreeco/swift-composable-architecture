extension _Reducer where Action: BindableAction, Action.State == State {
  public func binding() -> ReducerBinding<Self> {
    .init(upstream: self)
  }
}

public struct ReducerBinding<Upstream: _Reducer>: _Reducer
where
  Upstream.Action: BindableAction,
  Upstream.Action.State == Upstream.State
{
  public let upstream: Upstream

  public func reduce(
    into state: inout Upstream.State,
    action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {

    guard let bindingAction = (/Upstream.Action.binding).extract(from: action)
    else {
      return self.upstream.reduce(into: &state, action: action)
    }

    bindingAction.set(&state)
    return self.upstream.reduce(into: &state, action: action)
  }
}
