extension ReducerProtocol {
  @inlinable
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: WritableKeyPath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>
  ) -> Pullback<GlobalState, GlobalAction, Self> {
    Pullback(state: toLocalState, action: toLocalAction) {
      self
    }
  }
}

public struct Pullback<State, Action, Local: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let toLocalState: WritableKeyPath<State, Local.State>

  @usableFromInline
  let toLocalAction: CasePath<Action, Local.Action>

  @usableFromInline
  let localReducer: Local

  @inlinable
  public init(
    state toLocalState: WritableKeyPath<State, Local.State>,
    action toLocalAction: CasePath<Action, Local.Action>,
    @ReducerBuilder<Local.State, Local.Action> _ local: () -> Local
  ) {
    self.toLocalState = toLocalState
    self.toLocalAction = toLocalAction
    self.localReducer = local()
  }

  @inlinable
  public func reduce(
    into state: inout State, action: Action
  ) -> Effect<Action, Never> {
    guard let localAction = self.toLocalAction.extract(from: action)
    else { return .none }
    return self.localReducer
      .reduce(into: &state[keyPath: self.toLocalState], action: localAction)
      .map(self.toLocalAction.embed)
  }
}

public typealias Scope = Pullback
