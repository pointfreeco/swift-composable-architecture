import CustomDump
import SwiftUI

/*
 TODO: Explore other formulations:

 var body: some ReducerProtocol<State, Action> {
   Bindings()
 }

 extension ReducerProtocol where Action: BindableAction, State == Action.State {
   // Apply bindings automatically?
   func reduce(into state: inout State, action: Action) { ... }
 }
 */

#if compiler(>=5.4)
  extension ReducerProtocol where Action: BindableAction, State == Action.State {
    @inlinable
    public func binding() -> BindingReducer<Self> {
      .init(base: self)
    }
  }

  public struct BindingReducer<Base: ReducerProtocol>: ReducerProtocol
  where Base.Action: BindableAction, Base.State == Base.Action.State {
    @usableFromInline
    let base: Base

    @usableFromInline
    init(base: Base) {
      self.base = base
    }

    @inlinable
    public func reduce(
      into state: inout Base.State, action: Base.Action
    ) -> Effect<Base.Action, Never> {
      guard let bindingAction = (/Base.Action.binding).extract(from: action)
      else {
        return self.base.reduce(into: &state, action: action)
      }

      bindingAction.set(&state)
      return self.base.reduce(into: &state, action: action)
    }
  }
#endif
