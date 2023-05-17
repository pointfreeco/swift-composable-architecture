import SwiftUI

extension View {
  /// Presents a modal view that covers as much of the screen as possible using the store you
  /// provide as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `fullScreenCover` view
  /// > modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a sheet
  ///     you create that the system displays to the user. If `store`'s state is `nil`-ed out, the
  ///     system dismisses the currently displayed sheet.
  ///   - onDismiss: The closure to execute when dismissing the modal view.
  ///   - content: A closure returning the content of the modal view.
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.modifier(
      PresentationFullScreenCoverModifier(
        store: store,
        state: { $0 },
        id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } },
        action: { $0 },
        onDismiss: onDismiss,
        content: content
      )
    )
  }

  /// Presents a modal view that covers as much of the screen as possible using the store you
  /// provide as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `fullScreenCover` view
  /// > modifier.
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
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationFullScreenCoverModifier(
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

@available(iOS 14, macCatalyst 14, tvOS 14, watchOS 7, *)
@available(macOS, unavailable)
private struct PresentationFullScreenCoverModifier<
  State,
  ID: Hashable,
  Action,
  DestinationState,
  DestinationAction,
  CoverContent: View
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let toID: (PresentationState<State>) -> ID?
  let fromDestinationAction: (DestinationAction) -> Action
  let onDismiss: (() -> Void)?
  let coverContent: (Store<DestinationState, DestinationAction>) -> CoverContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onDismiss: (() -> Void)?,
    content coverContent: @escaping (Store<DestinationState, DestinationAction>) -> CoverContent
  ) {
    let filteredStore = store
      .invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
      .filterSend { state, _ in
        state.wrappedValue.flatMap(toDestinationState) == nil ? !BindingLocal.isActive : true
      }
    self.store = filteredStore
    self.viewStore = ViewStore(
      filteredStore,
      removeDuplicates: { $0.id == $1.id }
    )
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.onDismiss = onDismiss
    self.coverContent = coverContent
  }

  func body(content: Content) -> some View {
    let id = self.viewStore.id
    content.fullScreenCover(
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
        then: self.coverContent
      )
    }
  }
}
