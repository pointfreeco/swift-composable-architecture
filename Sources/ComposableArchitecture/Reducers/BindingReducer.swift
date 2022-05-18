import CustomDump
import SwiftUI

#if compiler(>=5.4)
  extension ReducerProtocol where Action: BindableAction, State == Action.State {
    @inlinable
    public func binding() -> BindingReducer<Self> {
      .init(upstream: self)
    }
    
    @inlinable
    public func bindingWithBody() -> BindingReducerWithBody<Self> {
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

@usableFromInline
struct BindingActionReducer<State, Action>: ReducerProtocol
where Action: BindableAction, Action.State == State {
  @usableFromInline
  init() {}
  
  @inlinable
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    (/Action.binding).extract(from: action)?.set(&state)
    return .none
  }
}

public struct BindingReducerWithBody<Upstream: ReducerProtocol>: ReducerProtocol
where Upstream.Action: BindableAction, Upstream.State == Upstream.Action.State {
  @usableFromInline
  let upstream: Upstream

  @usableFromInline
  init(upstream: Upstream) {
    self.upstream = upstream
  }
  
  @inlinable
  public var body: some ReducerProtocol<Upstream.State, Upstream.Action> {
    BindingActionReducer()
    upstream
  }
}
#endif
