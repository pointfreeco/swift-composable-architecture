import SwiftUI

extension View {
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.sheet(store: store, state: { $0 }, action: { $0 }, content: content)
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
        action: fromDestinationAction,
        content: content
      )
    )
  }
}

private struct PresentationSheetModifier<
  State,
  Action,
  DestinationState,
  DestinationAction,
  SheetContent: View
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let sheetContent: (Store<DestinationState, DestinationAction>) -> SheetContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    content sheetContent: @escaping (Store<DestinationState, DestinationAction>) -> SheetContent
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store.filter { state, _ in state.wrappedValue != nil },
      removeDuplicates: { $0.id == $1.id }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.sheetContent = sheetContent
  }

  func body(content: Content) -> some View {
    content.sheet(
      item: self.viewStore.binding(
        get: { $0.wrappedValue.flatMap(self.toDestinationState) != nil ? $0.id : nil },
        send: .dismiss
      )
    ) { _ in
      IfLetStore(
        self.store.scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.sheetContent
      )
    }
  }
}

