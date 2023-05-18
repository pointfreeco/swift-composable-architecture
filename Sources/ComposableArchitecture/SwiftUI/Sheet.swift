import SwiftUI

extension View {
  /// Presents a sheet using the given store as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `sheet` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a sheet
  ///     you create that the system displays to the user. If `store`'s state is `nil`-ed out, the
  ///     system dismisses the currently displayed sheet.
  ///   - onDismiss: The closure to execute when dismissing the modal view.
  ///   - content: A closure returning the content of the modal view.
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.modifier(
      PresentationSheetModifier(
        store: store,
        state: { $0 },
        id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } },
        action: { $0 },
        onDismiss: onDismiss,
        content: content
      )
    )
  }

  /// Presents a sheet using the given store as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `sheet` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a sheet
  ///     you create that the system displays to the user. If `store`'s state is `nil`-ed out, the
  ///     system dismisses the currently displayed sheet.
  ///   - toDestinationState: A transformation to extract modal state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed modal actions into the presentation
  ///     action.
  ///   - onDismiss: The closure to execute when dismissing the modal view.
  ///   - content: A closure returning the content of the modal view.
  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationSheetModifier(
        store: store,
        state: toDestinationState,
        id: { $0.id },
        action: fromDestinationAction,
        onDismiss: onDismiss,
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
  let onDismiss: (() -> Void)?
  let sheetContent: (Store<DestinationState, DestinationAction>) -> SheetContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onDismiss: (() -> Void)?,
    content sheetContent: @escaping (Store<DestinationState, DestinationAction>) -> SheetContent
  ) {
    let filteredStore = store
      .invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
      .filterSend { state, _ in
        state.wrappedValue.flatMap(toDestinationState) == nil ? !BindingLocal.isActive : true
      }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore, observe: { $0 }, removeDuplicates: { $0.id == $1.id })
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.onDismiss = onDismiss
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
      ),
      onDismiss: self.onDismiss
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
