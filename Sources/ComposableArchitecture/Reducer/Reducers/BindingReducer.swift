import SwiftUI

/// A reducer that updates bindable state when it receives binding actions.
public struct BindingReducer<State, Action, ViewAction: BindableAction>: ReducerProtocol
where State == ViewAction.State {
  @usableFromInline
  let toViewAction: (Action) -> ViewAction?

  /// Initializes a reducer that updates bindable state when it receives binding actions.
  @inlinable
  public init() where Action == ViewAction {
    self.init(internal: { $0 })
  }

  @inlinable
  public init(action toViewAction: @escaping (Action) -> ViewAction?) {
    self.init(internal: toViewAction)
  }

  @usableFromInline
  init(internal toViewAction: @escaping (Action) -> ViewAction?) {
    self.toViewAction = toViewAction
  }

  @inlinable
  public func reduce(
    into state: inout State, action: Action
  ) -> EffectTask<Action> {
    guard let bindingAction = self.toViewAction(action).flatMap(/ViewAction.binding)
    else { return .none }

    bindingAction.set(&state)
    return .none
  }
}
