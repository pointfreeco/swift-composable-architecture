extension ReducerProtocol {
  #if swift(>=5.7)
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
    /// The `ifLet` forces a specific order of operations for the child and parent features. It runs
    /// the child first, and then the parent. If the order was reversed, then it would be possible for
    /// the parent feature to `nil` out the child state, in which case the child feature would not be
    /// able to react to that action. That can cause subtle bugs.
    ///
    /// It is still possible for a parent feature higher up in the application to `nil` out child
    /// state before the child has a chance to react to the action. In such cases a runtime warning
    /// is shown in Xcode to let you know that there's a potential problem.
    ///
    /// - Parameters:
    ///   - toWrappedState: A writable key path from parent state to a property containing optional
    ///     child state.
    ///   - toWrappedAction: A case path from parent action to a case containing child actions.
    ///   - wrapped: A reducer that will be invoked with child actions against non-optional child
    ///     state.
    /// - Returns: A reducer that combines the child reducer with the parent reducer.
    @inlinable
    public func ifLet<WrappedState, WrappedAction>(
      _ toWrappedState: WritableKeyPath<State, WrappedState?>,
      action toWrappedAction: CasePath<Action, WrappedAction>,
      @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> some ReducerProtocol<
        WrappedState, WrappedAction
      >,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> some ReducerProtocol<State, Action> {
      _ContainedStateReducer(
        parent: self,
        toStateContainer: toWrappedState,
        toContentAction: toWrappedAction.with(tag: WrappedState.self),
        content: wrapped(),
        file: file,
        fileID: fileID,
        line: line,
        onStateExtractionFailure: self.onNilState()
      )
    }
  #else
    @inlinable
    public func ifLet<Wrapped: ReducerProtocol>(
      _ toWrappedState: WritableKeyPath<State, Wrapped.State?>,
      action toWrappedAction: CasePath<Action, Wrapped.Action>,
      @ReducerBuilderOf<Wrapped> then wrapped: () -> Wrapped,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> _ContainedStateReducer<
      Self, WritableKeyPath<Self.State, Wrapped.State?>, Wrapped.State?, Wrapped
    > {
      _ContainedStateReducer(
        parent: self,
        toStateContainer: toWrappedState,
        toContentAction: toWrappedAction.with(tag: Wrapped.State.self),
        content: wrapped(),
        file: file,
        fileID: fileID,
        line: line,
        onStateExtractionFailure: self.onNilState()
      )
    }
  #endif
}

extension ReducerProtocol {
  @usableFromInline
  func onNilState() -> StateExtractionFailureHandler<State, Action> {
    .init { state, action, file, fileID, line in
      runtimeWarn(
        """
        An "ifLet" at "\(fileID):\(line)" received a child action when child state was \
        "nil". …

          Action:
            \(debugCaseOutput(action))

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
        file: file,
        line: line
      )
    }
  }
}

extension Optional: MutableStateContainer {
  public func extract(tag: Wrapped.Type) -> Wrapped? {
    self
  }
  public mutating func embed(tag: Wrapped.Type, state: Wrapped) {
    self = state
  }
  public mutating func modify<Result>(tag: Wrapped.Type, _ body: (inout Wrapped) -> Result)
    throws -> Result
  {
    guard var value = self else { throw StateExtractionFailed() }
    defer { self = value }
    return body(&value)
  }
}
