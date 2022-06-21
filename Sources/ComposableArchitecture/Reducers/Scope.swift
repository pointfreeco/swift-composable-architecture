public struct Scope<State, Action, Local: ReducerProtocol>: ReducerProtocol {
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

// TODO: Single interface with `Scope`?
// TODO: Use `ifLet`, or `ifCaseLet`, or `switch` instead?
public struct ScopeCase<State, Action, Local: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let toLocalState: CasePath<State, Local.State>

  @usableFromInline
  let toLocalAction: CasePath<Action, Local.Action>

  @usableFromInline
  let localReducer: Local

  @inlinable
  public init(
    state toLocalState: CasePath<State, Local.State>,
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

    guard var localState = toLocalState.extract(from: state) else {
//      runtimeWarning(
//        """
//        A reducer pulled back from "%@:%d" received an action when local state was \
//        unavailable. …
//
//          Action:
//            %@
//
//        This is generally considered an application logic error, and can happen for a few \
//        reasons:
//
//        • The reducer for a particular case of state was combined with or run from another \
//        reducer that set "%@" to another case before the reducer ran. Combine or run \
//        case-specific reducers before reducers that may set their state to another case. This \
//        ensures that case-specific reducers can handle their actions while their state is \
//        available.
//
//        • An in-flight effect emitted this action when state was unavailable. While it may be \
//        perfectly reasonable to ignore this action, you may want to cancel the associated \
//        effect before state is set to another case, especially if it is a long-living effect.
//
//        • This action was sent to the store while state was another case. Make sure that \
//        actions for this reducer can only be sent to a view store when state is non-"nil". \
//        In SwiftUI applications, use "SwitchStore".
//        """,
//        [
//          "\(file)",
//          line,
//          debugCaseOutput(localAction),
//          "\(State.self)",
//        ]
//      )
      return .none
    }
    defer { state = self.toLocalState.embed(localState) }

    return self.localReducer
      .reduce(into: &localState, action: localAction)
      .map(self.toLocalAction.embed)
  }
}
