extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on a case of parent enum state.
  ///
  /// For example, if a parent feature's state is expressed as an enum of multiple children
  /// states, then `ifCaseLet` can run a child reducer on a particular case of the enum:
  ///
  /// ```swift
  /// struct Parent: ReducerProtocol {
  ///   enum State {
  ///     case loggedIn(Authenticated.State)
  ///     case loggedOut(Unauthenticated.State)
  ///   }
  ///   enum Action {
  ///     case loggedIn(Authenticated.Action)
  ///     case loggedOut(Unauthenticated.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifCaseLet(/State.loggedIn, action: /Action.loggedIn) {
  ///       Authenticated()
  ///     }
  ///     .ifCaseLet(/State.loggedOut, action: /Action.loggedOut) {
  ///       Unauthenticated()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifCaseLet` forces a specific order of operations for the child and parent features. It
  /// runs the child first, and then the parent. If the order was reversed, then it would be
  /// possible for the parent feature to change the case of the enum, in which case the child
  /// feature would not be able to react to that action. That can cause subtle bugs.
  ///
  /// It is still possible for a parent feature higher up in the application to change the case of
  /// the enum before the child has a chance to react to the action. In such cases a runtime
  /// warning is shown in Xcode to let you know that there's a potential problem.
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

  @usableFromInline
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
  ) -> EffectTask<Parent.Action> {
    self.reduceChild(into: &state, action: action)
      .merge(with: self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard var childState = self.toChildState.extract(from: state) else {
      runtimeWarn(
        """
        An "ifCaseLet" at "\(self.fileID):\(self.line)" received a child action when child state \
        was set to a different case. …

          Action:
            \(debugCaseOutput(action))
          State:
            \(debugCaseOutput(state))

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set "\(typeName(Parent.State.self))" to a different case before this \
        reducer ran. This reducer must run before any other reducer sets child state to a \
        different case. This ensures that child reducers can handle their actions while their \
        state is still available.

        • An in-flight effect emitted this action when child state was unavailable. While it may \
        be perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state changes to another case, especially if it is a long-living effect.

        • This action was sent to the store while state was another case. Make sure that actions \
        for this reducer can only be sent from a view store when state is set to the appropriate \
        case. In SwiftUI applications, use "SwitchStore".
        """,
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
