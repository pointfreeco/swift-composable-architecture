public struct Feature<State, Action, ChildState, ChildAction> {
  public let toChildState: KeyPath<State, ChildState>
  public let toChildAction: (ChildAction) -> Action

  public init(
    state toChildState: KeyPath<State, ChildState>,
    action toChildAction: @escaping (ChildAction) -> Action
  ) {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
  }
}

extension Store {
  public func scope<ChildState, ChildAction>(
    _ feature: Feature<State, Action, ChildState, ChildAction>
  ) -> Store<ChildState, ChildAction> {
    self.scope(
      state: { $0[keyPath: feature.toChildState] },
      action: feature.toChildAction
    )
  }
}
