import CustomDump
import SwiftUI

#if compiler(>=5.4)
  public struct BindingReducer<State, Action>: ReducerProtocol
  where Action: BindableAction, State == Action.State {
    @inlinable
    public init() {}

    @inlinable
    public func reduce(
      into state: inout State, action: Action
    ) -> Effect<Action, Never> {
      guard let bindingAction = (/Action.binding).extract(from: action)
      else {
        return .none
      }

      bindingAction.set(&state)
      return .none
    }
  }
#endif
