extension _Reducer {
  @inlinable
  public func forEach<GlobalState, GlobalAction, ID>(
    state toArrayState: WritableKeyPath<GlobalState, IdentifiedArray<ID, Self.State>>,
    action toElementAction: CasePath<GlobalAction, (ID, Self.Action)>,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducers.ForEach<Self, GlobalState, GlobalAction, ID> {
    .init(
      self,
      state: toArrayState,
      action: toElementAction,
      file: file,
      line: line
    )
  }
}

extension Reducers {
  public struct ForEach<ElementReducer, State, Action, ID>: _Reducer
  where ElementReducer: _Reducer, ID: Hashable {
    public let elementReducer: ElementReducer
    public let toArrayState: WritableKeyPath<State, IdentifiedArray<ID, ElementReducer.State>>
    public let toElementAction: CasePath<Action, (ID, ElementReducer.Action)>
    public let file: StaticString
    public let line: UInt

    @Dependency(\.breakpointsEnabled) public var breakpointOnNil

    @inlinable
    public init(
      _ elementReducer: ElementReducer,
      state toArrayState: WritableKeyPath<State, IdentifiedArray<ID, ElementReducer.State>>,
      action toElementAction: CasePath<Action, (ID, ElementReducer.Action)>,
      file: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.elementReducer = elementReducer
      self.toArrayState = toArrayState
      self.toElementAction = toElementAction
      self.file = file
      self.line = line
    }

    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
      guard let (id, elementAction) = self.toElementAction.extract(from: action)
      else { return .none }

      if state[keyPath: self.toArrayState][id: id] == nil {
        if self.breakpointOnNil {
          breakpoint(
            """
            ---
            Warning: Reducer.forEach@\(file):\(line)

            "\(debugCaseOutput(elementAction))" was received by a "forEach" reducer at id \(id) \
            when its state contained no element at this id. This is generally considered an \
            application logic error, and can happen for a few reasons:

            * This "forEach" reducer was combined with or run from another reducer that removed \
            the element at this id when it handled this action. To fix this make sure that this \
            "forEach" reducer is run before any other reducers that can move or remove elements \
            from state. This ensures that "forEach" reducers can handle their actions for the \
            element at the intended id.

            * An in-flight effect emitted this action while state contained no element at this id. \
            It may be perfectly reasonable to ignore this action, but you also may want to cancel \
            the effect it originated from when removing an element from the identified array, \
            especially if it is a long-living effect.

            * This action was sent to the store while its state contained no element at this id. \
            To fix this make sure that actions for this reducer can only be sent to a view store \
            when its state contains an element at this id. In SwiftUI applications, use \
            "ForEachStore".
            ---
            """
          )
        }
        return .none
      }
      return
        self
        .elementReducer.reduce(
          into: &state[keyPath: self.toArrayState][id: id]!,
          action: elementAction
        )
        .map { self.toElementAction.embed((id, $0)) }
    }
  }
}
