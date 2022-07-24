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
      .init(upstream: self)
    }
  }

  public struct BindingReducer<Upstream: ReducerProtocol>: ReducerProtocol
  where Upstream.Action: BindableAction, Upstream.State == Upstream.Action.State {
    @usableFromInline
    let upstream: Upstream

    @usableFromInline
    init(upstream: Upstream) {
      self.upstream = upstream
    }

    @inlinable
    public func reduce(
      into state: inout Upstream.State, action: Upstream.Action
    ) -> Effect<Upstream.Action, Never> {
      guard let bindingAction = (/Upstream.Action.binding).extract(from: action)
      else {
        return self.upstream.reduce(into: &state, action: action)
      }

      bindingAction.set(&state)
      return self.upstream.reduce(into: &state, action: action)
    }
  }
#endif
