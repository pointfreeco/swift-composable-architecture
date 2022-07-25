extension ReducerProtocol {
  @inlinable
  public func ifLet<Wrapped: ReducerProtocol>(
    state toWrappedState: WritableKeyPath<State, Wrapped.State?>,
    action toWrappedAction: CasePath<Action, Wrapped.Action>,
    @ReducerBuilder<Wrapped.State, Wrapped.Action> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    line: UInt = #line
  ) -> IfLetReducer<Self, Wrapped> {
    .init(
      upstream: self,
      wrapped: wrapped(),
      toWrappedState: toWrappedState,
      toWrappedAction: toWrappedAction,
      file: file,
      line: line
    )
  }

  @inlinable
  public func ifLet<Wrapped: ReducerProtocol>(
    state toWrappedState: CasePath<State, Wrapped.State>,
    action toWrappedAction: CasePath<Action, Wrapped.Action>,
    @ReducerBuilder<Wrapped.State, Wrapped.Action> then wrapped: () -> Wrapped,
    file: StaticString = #file,
    line: UInt = #line
  ) -> IfCaseLetReducer<Self, Wrapped> {
    .init(
      upstream: self,
      wrapped: wrapped(),
      toWrappedState: toWrappedState,
      toWrappedAction: toWrappedAction,
      file: file,
      line: line
    )
  }
}

public struct IfLetReducer<Upstream: ReducerProtocol, Wrapped: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let wrapped: Wrapped

  @usableFromInline
  let toWrappedState: WritableKeyPath<State, Wrapped.State?>

  @usableFromInline
  let toWrappedAction: CasePath<Action, Wrapped.Action>

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    upstream: Upstream,
    wrapped: Wrapped,
    toWrappedState: WritableKeyPath<State, Wrapped.State?>,
    toWrappedAction: CasePath<Action, Wrapped.Action>,
    file: StaticString,
    line: UInt
  ) {
    self.upstream = upstream
    self.wrapped = wrapped
    self.toWrappedState = toWrappedState
    self.toWrappedAction = toWrappedAction
    self.file = file
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    return .merge(
      self.reduceWrapped(into: &state, action: action),
      self.upstream.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceWrapped(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard let wrappedAction = self.toWrappedAction.extract(from: action)
    else { return .none }
    guard state[keyPath: self.toWrappedState] != nil else {
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
          "\(file)",
          line,
          debugCaseOutput(action),
          "\(Wrapped.State.self)",
        ]
      )
      return .none
    }
    return self.wrapped.reduce(into: &state[keyPath: self.toWrappedState]!, action: wrappedAction)
      .map(self.toWrappedAction.embed)
  }
}

public struct IfCaseLetReducer<Upstream: ReducerProtocol, Wrapped: ReducerProtocol>: ReducerProtocol
{
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  let wrapped: Wrapped

  @usableFromInline
  let toWrappedState: CasePath<State, Wrapped.State>

  @usableFromInline
  let toWrappedAction: CasePath<Action, Wrapped.Action>

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    upstream: Upstream,
    wrapped: Wrapped,
    toWrappedState: CasePath<State, Wrapped.State>,
    toWrappedAction: CasePath<Action, Wrapped.Action>,
    file: StaticString,
    line: UInt
  ) {
    self.upstream = upstream
    self.wrapped = wrapped
    self.toWrappedState = toWrappedState
    self.toWrappedAction = toWrappedAction
    self.file = file
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    return .merge(
      self.reduceWrapped(into: &state, action: action),
      self.upstream.reduce(into: &state, action: action)
    )
  }

  @inlinable
  func reduceWrapped(
    into state: inout Upstream.State, action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    guard let wrappedAction = self.toWrappedAction.extract(from: action)
    else { return .none }
    guard var wrappedState = self.toWrappedState.extract(from: state) else {
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
          "\(file)",
          line,
          debugCaseOutput(action),
          "\(Wrapped.State.self)",
        ]
      )
      return .none
    }
    defer { state = self.toWrappedState.embed(wrappedState) }
    return self.wrapped.reduce(into: &wrappedState, action: wrappedAction)
      .map(self.toWrappedAction.embed)
  }
}
