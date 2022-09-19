extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// - Parameters:
  ///   - toWrappedState: A writable key path from parent state to a property containing optional
  ///     child state.
  ///   - toWrappedAction: A case path from parent action to a case containing child actions.
  ///   - wrapped: A reducer that will be invoked with child actions against non-optional child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func ifLet<Wrapped: ReducerProtocol>(
    _ toWrappedState: WritableKeyPath<State, Wrapped.State?>,
    action toWrappedAction: CasePath<Action, Wrapped.Action>,
    @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped> {
    .init(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _IfLetReducer<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let toChildState: WritableKeyPath<Parent.State, Child.State?>

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
    toChildState: WritableKeyPath<Parent.State, Child.State?>,
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
      .merge(with:  self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard state[keyPath: self.toChildState] != nil else {
      runtimeWarning(
        """
        An "ifLet" at "%@:%d" received a child action when child state was "nil". …

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set child state to "nil" before this reducer ran. This reducer must \
        run before any other reducer sets child state to "nil". This ensures that child reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was "nil". While it may be \
        perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state becomes "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
        applications, use "IfLetStore".
        """,
        [
          "\(self.fileID)",
          self.line,
          debugCaseOutput(action),
          typeName(Child.State.self),
        ],
        file: self.file,
        line: self.line
      )
      return .none
    }
    return self.child.reduce(into: &state[keyPath: self.toChildState]!, action: childAction)
      .map(self.toChildAction.embed)
  }
}
