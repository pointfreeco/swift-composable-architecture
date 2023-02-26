extension ReducerProtocol {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// For example, if a parent feature holds onto a piece of optional child state, then it can
  /// perform its core logic _and_ the child's logic by using the `ifLet` operator:
  ///
  /// ```swift
  /// struct Parent: ReducerProtocol {
  ///   struct State {
  ///     var child: Child.State?
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case child(Child.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifLet(\.child, action: /Action.child) {
  ///       Child()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifLet` operator does a number of things to try to enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features. It runs the
  ///     child first, and then the parent. If the order was reversed, then it would be possible for
  ///     the parent feature to `nil` out the child state, in which case the child feature would not
  ///     be able to react to that action. That can cause subtle bugs.
  ///
  ///   * It automatically cancels all child effects when it detects the child's state is `nil`'d
  ///     out.
  ///
  ///   * Automatically `nil`s out child state when an action is sent for alerts and confirmation
  ///     dialogs.
  ///
  /// See ``ReducerProtocol/ifLet(_:action:then:file:fileID:line:)-23pza`` for a more advanced
  /// operator suited to navigation.
  ///
  /// - Parameters:
  ///   - toWrappedState: A writable key path from parent state to a property containing optional
  ///     child state.
  ///   - toWrappedAction: A case path from parent action to a case containing child actions.
  ///   - wrapped: A reducer that will be invoked with child actions against non-optional child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  public func ifLet<WrappedState, WrappedAction, Wrapped: ReducerProtocol>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: CasePath<Action, WrappedAction>,
    @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _IfLetReducer<Self, Wrapped>
  where WrappedState == Wrapped.State, WrappedAction == Wrapped.Action {
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

  @usableFromInline
  @Dependency(\.navigationID) var navigationID

  @usableFromInline
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
  ) -> EffectTask<Parent.Action> {
    let childEffects = self.reduceChild(into: &state, action: action)

    let childIDBefore = state[keyPath: self.toChildState].map(AnyID.init)
    let parentEffects = self.parent.reduce(into: &state, action: action)
    let childIDAfter = state[keyPath: self.toChildState].map(AnyID.init)

    let childCancelEffects: EffectTask<Parent.Action>
    if let childID = childIDBefore, childID != childIDAfter {
      let id = self.navigationID
        .appending(path: self.toChildState)
        .appending(id: childID)
      childCancelEffects = .cancel(id: id)
    } else {
      childCancelEffects = .none
    }

    // TODO: can this just call ifCaseLet under the hood?

    return .merge(
      childEffects,
      parentEffects,
      childCancelEffects
    )
  }

  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    guard state[keyPath: self.toChildState] != nil else {
      var actionDump = ""
      customDump(action, to: &actionDump, indent: 4)
      runtimeWarn(
        """
        An "ifLet" at "\(self.fileID):\(self.line)" received a child action when child state was \
        "nil". …

          Action:
        \(actionDump)

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set child state to "nil" before this reducer ran. This reducer must run \
        before any other reducer sets child state to "nil". This ensures that child reducers can \
        handle their actions while their state is still available.

        • An in-flight effect emitted this action when child state was "nil". While it may be \
        perfectly reasonable to ignore this action, consider canceling the associated effect \
        before child state becomes "nil", especially if it is a long-living effect.

        • This action was sent to the store while state was "nil". Make sure that actions for this \
        reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
        applications, use "IfLetStore".
        """,
        file: self.file,
        line: self.line
      )
      return .none
    }
    let id = self.navigationID
      .appending(path: self.toChildState)
      .appending(component: state[keyPath: self.toChildState]!)

    defer {
      if Child.State.self is _EphemeralState.Type {
        state[keyPath: toChildState] = nil
      }
    }

    return self.child
      .dependency(\.navigationID, id)
      .reduce(into: &state[keyPath: self.toChildState]!, action: childAction)
      .map { self.toChildAction.embed($0) }
      .cancellable(id: id)
  }
}
