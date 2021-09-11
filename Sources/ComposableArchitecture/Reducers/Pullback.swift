extension _Reducer {
  @inlinable
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: WritableKeyPath<GlobalState, Self.State>,
    action toLocalAction: CasePath<GlobalAction, Self.Action>
  ) -> Reducers.PullbackStruct<Self, GlobalState, GlobalAction> {
    .init(self, state: toLocalState, action: toLocalAction)
  }

  @inlinable
  public func pullback<GlobalState, GlobalAction>(
    state toLocalState: CasePath<GlobalState, Self.State>,
    action toLocalAction: CasePath<GlobalAction, Self.Action>,
    breakpointOnNil: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducers.PullbackEnum<Self, GlobalState, GlobalAction> {
    .init(
      self,
      state: toLocalState,
      action: toLocalAction,
      breakpointOnNil: breakpointOnNil,
      file: file,
      line: line
    )
  }
}

extension Reducers {
  public struct PullbackStruct<LocalReducer, State, Action>: _Reducer
  where LocalReducer: _Reducer {
    public let localReducer: LocalReducer
    public let toLocalState: WritableKeyPath<State, LocalReducer.State>
    public let toLocalAction: CasePath<Action, LocalReducer.Action>

    @inlinable
    public init(
      _ localReducer: LocalReducer,
      state toLocalState: WritableKeyPath<State, LocalReducer.State>,
      action toLocalAction: CasePath<Action, LocalReducer.Action>
    ) {
      self.localReducer = localReducer
      self.toLocalState = toLocalState
      self.toLocalAction = toLocalAction
    }

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      guard let localAction = toLocalAction.extract(from: action) else { return .none }
      return self.localReducer.reduce(into: &state[keyPath: toLocalState], action: localAction)
        .map(toLocalAction.embed)
        .eraseToEffect()
    }
  }

  public struct PullbackEnum<LocalReducer, State, Action>: _Reducer
  where LocalReducer: _Reducer {
    public let localReducer: LocalReducer
    public let toLocalState: CasePath<State, LocalReducer.State>
    public let toLocalAction: CasePath<Action, LocalReducer.Action>
    public let breakpointOnNil: Bool
    public let file: StaticString
    public let line: UInt

    @inlinable
    public init(
      _ localReducer: LocalReducer,
      state toLocalState: CasePath<State, LocalReducer.State>,
      action toLocalAction: CasePath<Action, LocalReducer.Action>,
      breakpointOnNil: Bool = true,
      file: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.localReducer = localReducer
      self.toLocalState = toLocalState
      self.toLocalAction = toLocalAction
      self.breakpointOnNil = breakpointOnNil
      self.file = file
      self.line = line
    }

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      guard let localAction = toLocalAction.extract(from: action) else { return .none }

      guard var localState = toLocalState.extract(from: state) else {
        if breakpointOnNil {
          breakpoint(
            """
            ---
            Warning: Reducer.pullback@\(file):\(line)

            "\(debugCaseOutput(localAction))" was received by a reducer when its state was \
            unavailable. This is generally considered an application logic error, and can happen \
            for a few reasons:

            * The reducer for a particular case of state was combined with or run from another \
            reducer that set "\(State.self)" to another case before the reducer ran. Combine or \
            run case-specific reducers before reducers that may set their state to another case. \
            This ensures that case-specific reducers can handle their actions while their state \
            is available.

            * An in-flight effect emitted this action when state was unavailable. While it may be \
            perfectly reasonable to ignore this action, you may want to cancel the associated \
            effect before state is set to another case, especially if it is a long-living effect.

            * This action was sent to the store while state was another case. Make sure that \
            actions for this reducer can only be sent to a view store when state is non-"nil". \
            In SwiftUI applications, use "SwitchStore".
            ---
            """
          )
        }
        return .none
      }
      defer { state = toLocalState.embed(localState) }
      return self.localReducer.reduce(into: &localState, action: localAction)
        .map(toLocalAction.embed)
    }
  }
}
