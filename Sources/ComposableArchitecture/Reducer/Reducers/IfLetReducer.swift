extension ReducerProtocol {
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

  @inlinable
  public func ifCaseLet<Wrapped: ReducerProtocol>(
    _ toWrappedState: CasePath<State, Wrapped.State>,
    action toWrappedAction: CasePath<Action, Wrapped.Action>,
    @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfCaseLetReducer<Self, Wrapped> {
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
    return .merge(
      self.reduceChild(into: &state, action: action),
      self.parent.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard state[keyPath: self.toChildState] != nil else {
      // TODO: Update language
      runtimeWarning(
        """
        An "ifLet" reducer at "%@:%d" received an action when state was "nil". …

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • The optional reducer was combined with or run from another reducer that set "%@" to \
        "nil" before the optional reducer ran. Combine or run optional reducers before reducers \
        that can set their state to "nil". This ensures that optional reducers can handle their \
        actions while their state is still non-"nil".

        • An in-flight effect emitted this action while state was "nil". While it may be perfectly \
        reasonable to ignore this action, you may want to cancel the associated effect before \
        state is set to "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent to a view store when state is non-"nil". In SwiftUI applications, \
        use "IfLetStore".
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
    return .merge(
      self.reduceChild(into: &state, action: action),
      self.parent.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action, Never> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard var childState = self.toChildState.extract(from: state) else {
      // TODO: Update language
      runtimeWarning(
        """
        An "ifLet" reducer at "%@:%d" received an action when state was "nil". …

          Action:
            %@

        This is generally considered an application logic error, and can happen for a few reasons:

        • The optional reducer was combined with or run from another reducer that set "%@" to \
        "nil" before the optional reducer ran. Combine or run optional reducers before reducers \
        that can set their state to "nil". This ensures that optional reducers can handle their \
        actions while their state is still non-"nil".

        • An in-flight effect emitted this action while state was "nil". While it may be perfectly \
        reasonable to ignore this action, you may want to cancel the associated effect before \
        state is set to "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent to a view store when state is non-"nil". In SwiftUI applications, \
        use "IfLetStore".
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
    defer { state = self.toChildState.embed(childState) }
    return self.child.reduce(into: &childState, action: childAction)
      .map(self.toChildAction.embed)
  }
}
