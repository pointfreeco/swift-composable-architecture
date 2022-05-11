public struct IfLetReducer<Wrapped: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let wrappedReducer: Wrapped

  @inlinable
  public init(@ReducerBuilder<Wrapped.State, Wrapped.Action> _ wrapped: () -> Wrapped) {
    self.wrappedReducer = wrapped()
  }

  @inlinable
  public func reduce(
    into state: inout Wrapped.State?, action: Wrapped.Action
  ) -> Effect<Wrapped.Action, Never> {
    guard state != nil else {
//      runtimeWarning(
//        """
//        An "optional" reducer at "%@:%d" received an action when state was "nil". …
//
//          Action:
//            %@
//
//        This is generally considered an application logic error, and can happen for a few \
//        reasons:
//
//        • The optional reducer was combined with or run from another reducer that set "%@" to \
//        "nil" before the optional reducer ran. Combine or run optional reducers before \
//        reducers that can set their state to "nil". This ensures that optional reducers can \
//        handle their actions while their state is still non-"nil".
//
//        • An in-flight effect emitted this action while state was "nil". While it may be \
//        perfectly reasonable to ignore this action, you may want to cancel the associated \
//        effect before state is set to "nil", especially if it is a long-living effect.
//
//        • This action was sent to the store while state was "nil". Make sure that actions for \
//        this reducer can only be sent to a view store when state is non-"nil". In SwiftUI \
//        applications, use "IfLetStore".
//        """,
//        [
//          "\(file)",
//          line,
//          debugCaseOutput(action),
//          "\(State.self)",
//        ]
//      )
      return .none
    }
    return self.wrappedReducer.reduce(into: &state!, action: action)
  }
}
