import SwiftUI

extension View {
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.modifier(
      PresentationSheetModifier(
        store: store,
        state: { $0 },
        id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } },
        action: { $0 },
        content: content
      )
    )
  }

  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationSheetModifier(
        store: store,
        state: toDestinationState,
        id: { $0.id },
        action: fromDestinationAction,
        content: content
      )
    )
  }
}

private struct PresentationSheetModifier<
  State,
  ID: Hashable,
  Action,
  DestinationState,
  DestinationAction,
  SheetContent: View
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let toID: (PresentationState<State>) -> ID?
  let fromDestinationAction: (DestinationAction) -> Action
  let sheetContent: (Store<DestinationState, DestinationAction>) -> SheetContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    content sheetContent: @escaping (Store<DestinationState, DestinationAction>) -> SheetContent
  ) {
    let filteredStore = store.filterSend { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(
      filteredStore,
      removeDuplicates: { $0.id == $1.id }
    )
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.sheetContent = sheetContent
  }

  func body(content: Content) -> some View {
    let id = self.viewStore.id
    content.sheet(
      item: Binding(  
        get: {
          self.viewStore.wrappedValue.flatMap(self.toDestinationState) != nil
            ? toID(self.viewStore.state).map { Identified($0) { $0 } }
            : nil
        },
        set: { newState in
          if newState == nil, self.viewStore.wrappedValue != nil, self.viewStore.id == id {
            self.viewStore.send(.dismiss)
          }
        }
      )
    ) { _ in
      IfLetStore(
        self.store
          .handleInvalidation(state: { $0.wrappedValue.flatMap(self.toDestinationState) })
          .scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.sheetContent
      )
    }
  }
}

extension Store {
  func handleInvalidation<Wrapped>(
    state: @escaping (State) -> Wrapped?
  ) -> Store<State, Action> {
    self.isInvalidated = { [weak self] in (self?.state.value).flatMap(state) == nil }
    return self
  }
}
