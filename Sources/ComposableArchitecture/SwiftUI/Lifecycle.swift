/// <#Description#>
public enum LifecycleAction<Action> {
  case onAppear
  case onDisappear
  case action(Action)
}

extension LifecycleAction: Equatable where Action: Equatable {}

extension Reducer {
  /// <#Description#>
  /// - Parameters:
  ///   - onAppear: <#onAppear description#>
  ///   - onDisappear: <#onDisappear description#>
  /// - Returns: <#description#>
  public func lifecycle(
    onAppear: @escaping (Environment) -> Effect<Action, Never>,
    onDisappear: @escaping (Environment) -> Effect<Never, Never>
  ) -> Reducer<State?, LifecycleAction<Action>, Environment> {

    return .init { state, lifecycleAction, environment in
      switch lifecycleAction {
      case .onAppear:
        return onAppear(environment).map(LifecycleAction.action)

      case .onDisappear:
        return onDisappear(environment).fireAndForget()

      case let .action(action):
        guard state != nil else {
          fatalError("TODO")
        }
        
        return self.run(&state!, action, environment)
          .map(LifecycleAction.action)
      }
    }
  }
}
