import SwiftUI

extension View {
  @_spi(Presentation)
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      body(self, $item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<State, Action>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: { $0 },
      id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } },
      action: { $0 },
      body: body
    )
  }

  @_spi(Presentation)
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ isPresented: Binding<Bool>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, destination in
      body(self, $item.isPresent(), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      _ content: Self,
      _ item: Binding<AnyIdentifiable?>,
      _ destination: DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      id: { $0.id },
      action: fromDestinationAction,
      body: body
    )
  }

  @ViewBuilder
  private func presentation<
    State,
    ID: Hashable,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body: @escaping (
      Self,
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>
    ) -> Content
  ) -> some View {
    let store = store.invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
    WithViewStore(store, removeDuplicates: { toID($0) == toID($1) }) { viewStore in
      body(
        self,
        viewStore.binding(
          get: {
            $0.wrappedValue.flatMap(toDestinationState) != nil
              ? toID($0).map { AnyIdentifiable(Identified($0) { $0 }) }
              : nil
          },
          send: .dismiss
        ),
        DestinationContent(
          store: store.scope(
            state: { $0.wrappedValue.flatMap(toDestinationState) },
            action: { .presented(fromDestinationAction($0)) }
          )
        )
      )
    }
  }
}

public struct AnyIdentifiable: Identifiable {
  public let base: Any
  public let id: AnyHashable

  public init<Base: Identifiable>(_ base: Base) {
    self.base = base
    self.id = base.id
  }
}

public struct DestinationContent<State, Action> {
  let store: Store<State?, Action>

  public func callAsFunction<Content: View>(
    @ViewBuilder _ body: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    IfLetStore(
      self.store.scope(state: returningLastNonNilValue { $0 }, action: { $0 }), then: body
    )
  }
}
