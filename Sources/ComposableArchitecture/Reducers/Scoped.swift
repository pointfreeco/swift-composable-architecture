extension Reducers {
  public class Scoped<State, Action, LocalState, LocalAction>: _Reducer {
    public let store: Store<State, Action>
    public let toLocalState: (State) -> LocalState
    public let fromLocalAction: (LocalAction) -> Action

    @usableFromInline
    init(
      store: Store<State, Action>,
      toLocalState: @escaping (State) -> LocalState,
      fromLocalAction: @escaping (LocalAction) -> Action
    ) {
      self.store = store
      self.toLocalState = toLocalState
      self.fromLocalAction = fromLocalAction
    }

    @usableFromInline
    var isSending = false

    @inlinable
    public func reduce(into state: inout LocalState, action: LocalAction)
    -> Effect<LocalAction, Never> {
      self.isSending = true
      defer { self.isSending = false }
      self.store.send(self.fromLocalAction(action))
      state = toLocalState(self.store.state.value)
      return .none
    }
  }
}
