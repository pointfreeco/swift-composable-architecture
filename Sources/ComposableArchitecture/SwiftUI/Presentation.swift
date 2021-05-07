import SwiftUI

public enum PresentationAction<Action> {
  case isPresented(Action)
  case onDismiss
  case present
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

extension Reducer {
  public func presents<LocalState, LocalAction, LocalEnvironment>(
    _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
    state toLocalState: WritableKeyPath<State, LocalState?>,
    action toPresentationAction: CasePath<Action, PresentationAction<LocalAction>>,
    environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
  ) -> Self {
    let id = UUID()
    return Self { state, action, environment in
      let wasPresented = state[keyPath: toLocalState] != nil
      return Self.combine(
        localReducer
          .cancellable(id: id)
          .optional()
          .pullback(
            state: toLocalState,
            action: toPresentationAction.appending(path: /PresentationAction.isPresented),
            environment: toLocalEnvironment),
        self,
        Reducer<State, PresentationAction<LocalAction>, Void> { state, action, _ in
          if case .onDismiss = action { state[keyPath: toLocalState] = nil }
          return wasPresented && state[keyPath: toLocalState] == nil ? .cancel(id: id) : .none
        }
        .pullback(state: \.self, action: toPresentationAction, environment: { _ in () })
      )
      .run(&state, action, environment)
    }
  }
}

extension View {
  public func sheet<State, Action, Content>(
    ifLet store: Store<State?, PresentationAction<Action>>,
    @ViewBuilder then content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.sheet(isPresented: viewStore.binding(send: .onDismiss)) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.isPresented),
          then: content
        )
      }
    }
  }

  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content>(
    ifLet store: Store<State?, PresentationAction<Action>>,
    @ViewBuilder then content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.fullScreenCover(isPresented: viewStore.binding(send: .onDismiss)) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.isPresented),
          then: content
        )
      }
    }
  }

  public func popover<State, Action, Content>(
    ifLet store: Store<State?, PresentationAction<Action>>,
    @ViewBuilder then content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.popover(isPresented: viewStore.binding(send: .onDismiss)) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.isPresented),
          then: content
        )
      }
    }
  }
}

extension Optional {
  static var cacheLastSome: (Self) -> Self {
    var lastWrapped: Wrapped?
    return {
      lastWrapped = $0 ?? lastWrapped
      return lastWrapped
    }
  }
}
