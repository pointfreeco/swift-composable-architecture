import SwiftUI

public struct PresentationModifier<
  State,
  Action,
  DestinationState,
  DestinationAction
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let modify:
    (
      Content,
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>
    ) -> AnyView  // TODO: Can we eliminate this erasure?

  public init<BodyContent: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body modify: @escaping (
      Content,
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>)
    -> BodyContent
  ) {
    let filteredStore = store.filterSend { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore, removeDuplicates: { $0.id == $1.id })
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.modify = {
      (
        content: Content, $item: Binding<AnyIdentifiable?>, destination: DestinationContent
      ) in AnyView(modify(content, $item, destination))
    }
  }

  public init<BodyContent: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body modify: @escaping (
      Content,
      Binding<Bool>,
      DestinationContent<DestinationState, DestinationAction>)
    -> BodyContent
  ) {
    let filteredStore = store.filterSend { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore, removeDuplicates: { $0.id == $1.id })
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.modify = {
      (
        content: Content, $item: Binding<AnyIdentifiable?>, destination: DestinationContent
      ) in AnyView(modify(content, $item.isPresent(), destination))
    }
  }

  public func body(content: Content) -> some View {
    let id = self.viewStore.id
    self.modify(
      content,
      Binding(  // TODO: Proper binding
        get: {
          self.viewStore.wrappedValue.flatMap(self.toDestinationState) != nil
            ? self.viewStore.id.map(AnyIdentifiable.init)
            : nil
        },
        set: { newState in
          if newState == nil, self.viewStore.wrappedValue != nil, self.viewStore.id == id {
            self.viewStore.send(.dismiss)
          }
        }
      ),
      DestinationContent(
        store: self.store.scope(
          state: { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        )
      )
    )
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
      self.store.scope(state: returningLastNonNilValue { $0 }), then: body
    )
  }
}
