extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on a case of parent state.
  ///
  /// - Parameters:
  ///   - toCaseState: A case path from parent state to a case containing child state.
  ///   - toCaseAction: A case path from parent action to a case containing child actions.
  ///   - case: A reducer that will be invoked with child actions against child state when it is
  ///     present
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func ifCaseLet<Case: ReducerProtocol>(
    _ toCaseState: CasePath<State, Case.State>,
    action toCaseAction: CasePath<Action, Case.Action>,
    @ReducerBuilderOf<Case> then case: () -> Case,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfCaseLetReducer<Self, Case> {
    .init(
      parent: self,
      child: `case`(),
      toChildState: toCaseState,
      toChildAction: toCaseAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _IfCaseLetReducer<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let toChildState: CasePath<Parent.State, Child.State>

  @usableFromInline
  let toChildAction: CasePath<Parent.Action, Child.Action>

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    parent: Parent,
    child: Child,
    toChildState: CasePath<Parent.State, Child.State>,
    toChildAction: CasePath<Parent.Action, Child.Action>,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.child = child
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    self.reduceChild(into: &state, action: action)
      .merge(with: self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard var childState = self.toChildState.extract(from: state) else {
      runtimeWarning(
        """
        An "ifCaseLet" at "%@:%d" received a child action when child state was set to a different \
        case. …

          Action:
            %@
          State:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set "%@" to a different case before this reducer ran. This reducer must \
        run before any other reducer sets child state to a different case. This ensures that child \
        reducers can handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was unavailable. While it may \
        be perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state changes to another case, especially if it is a long-living effect.

        • This action was sent to the store while state was another case. Make sure that actions \
        for this reducer can only be sent from a view store when state is set to the appropriate \
        case. In SwiftUI applications, use "SwitchStore".
        """,
        [
          "\(self.fileID)",
          self.line,
          debugCaseOutput(action),
          debugCaseOutput(state),
          typeName(Parent.State.self),
        ],
        file: self.file,
        line: self.line
      )
      return .none
    }
    defer { state = self.toChildState.embed(childState) }
    return self.child.reduce(into: &childState, action: childAction)
      .map(self.toChildAction.embed)
  }
}
