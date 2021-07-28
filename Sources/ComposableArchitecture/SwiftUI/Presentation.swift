import SwiftUI

public enum PresentationAction<Action> {
  case dismiss
  case presented(Action) // isActive
  case present
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

// TODO: do we need isActive versions

extension Reducer {
  public func presents<DestinationState, DestinationAction, DestinationEnvironment>(
    destination: Reducer<DestinationState, DestinationAction, DestinationEnvironment>,
    onDismiss: DestinationAction? = nil,
    state toDestinationState: WritableKeyPath<State, DestinationState?>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    environment toDestinationEnvironment: @escaping (Environment) -> DestinationEnvironment
  ) -> Self {
    return Self { state, action, environment in
      let wasPresented = state[keyPath: toDestinationState] != nil
      var effects: [Effect<Action, Never>] = []

      effects.append(
        destination
          .optional()
          .pullback(
            state: toDestinationState,
            action: toPresentationAction.appending(path: /PresentationAction.presented),
            environment: toDestinationEnvironment
          )
          .run(&state, action, environment)
      )
      let updatedDestinationState = state[keyPath: toDestinationState]

      effects.append(
        self
          .run(&state, action, environment)
      )

      if case .some(.dismiss) = toPresentationAction.extract(from: action) {
        state[keyPath: toDestinationState] = nil
      }
      if
        let onDismiss = onDismiss,
        wasPresented,
        state[keyPath: toDestinationState] == nil,
        var finalDestinationState = updatedDestinationState
      {
        effects.append(
          destination.run(
            &finalDestinationState,
            onDismiss,
            toDestinationEnvironment(environment)
          )
            .map(toPresentationAction.appending(path: /PresentationAction.presented).embed(_:))
        )
      }

      return .merge(effects)
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
      self.sheet(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.presented),
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
      self.fullScreenCover(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.presented),
          then: content
        )
      }
    }
  }

  @available(tvOS, unavailable)
  public func popover<State, Action, Content>(
    ifLet store: Store<State?, PresentationAction<Action>>,
    @ViewBuilder then content: @escaping (Store<State, Action>) -> Content
  ) -> some View
  where Content: View {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      self.popover(isPresented: viewStore.binding(send: { $0 ? .present : .dismiss })) {
        IfLetStore(
          store.scope(state: Optional.cacheLastSome, action: PresentationAction.presented),
          then: content
        )
      }
    }
  }
}

extension Optional {
  fileprivate static var cacheLastSome: (Self) -> Self {
    var lastWrapped: Wrapped?
    return {
      lastWrapped = $0 ?? lastWrapped
      return lastWrapped
    }
  }
}
