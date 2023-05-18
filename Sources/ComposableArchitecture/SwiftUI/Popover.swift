import SwiftUI

extension View {
  /// Presents a popover using the given store as a data source for the popover's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `popover` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a
  ///     popover you create that the system displays to the user. If `store`'s state is `nil`-ed
  ///     out, the system dismisses the currently displayed popover.
  ///   - attachmentAnchor: The positioning anchor that defines the attachment point of the popover.
  ///   - arrowEdge: The edge of the `attachmentAnchor` that defines the location of the popover's
  ///     arrow in macOS. iOS ignores this parameter.
  ///   - content: A closure returning the content of the popover.
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.modifier(
      PresentationPopoverModifier(
        store: store,
        state: { $0 },
        id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } },
        action: { $0 },
        attachmentAnchor: attachmentAnchor,
        arrowEdge: arrowEdge,
        content: content
      )
    )
  }

  /// Presents a popover using the given store as a data source for the popover's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `popover` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a
  ///     popover you create that the system displays to the user. If `store`'s state is `nil`-ed
  ///     out, the system dismisses the currently displayed popover.
  ///   - toDestinationState: A transformation to extract popover state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed popover actions into the presentation
  ///     action.
  ///   - attachmentAnchor: The positioning anchor that defines the attachment point of the popover.
  ///   - arrowEdge: The edge of the `attachmentAnchor` that defines the location of the popover's
  ///     arrow in macOS. iOS ignores this parameter.
  ///   - content: A closure returning the content of the popover.
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func popover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationPopoverModifier(
        store: store,
        state: toDestinationState,
        id: { $0.id },
        action: fromDestinationAction,
        attachmentAnchor: attachmentAnchor,
        arrowEdge: arrowEdge,
        content: content
      )
    )
  }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
private struct PresentationPopoverModifier<
  State,
  ID: Hashable,
  Action,
  DestinationState,
  DestinationAction,
  PopoverContent: View
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let toID: (PresentationState<State>) -> ID?
  let fromDestinationAction: (DestinationAction) -> Action
  let attachmentAnchor: PopoverAttachmentAnchor
  let arrowEdge: Edge
  let popoverContent: (Store<DestinationState, DestinationAction>) -> PopoverContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    content popoverContent: @escaping (Store<DestinationState, DestinationAction>) -> PopoverContent
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
    self.attachmentAnchor = attachmentAnchor
    self.arrowEdge = arrowEdge
    self.popoverContent = popoverContent
  }

  func body(content: Content) -> some View {
    let id = self.viewStore.id
    content.popover(
      item: Binding(  
        get: {
          self.viewStore.wrappedValue.flatMap(self.toDestinationState) != nil
            ? self.toID(self.viewStore.state).map { Identified($0) { $0 } }
            : nil
        },
        set: { newState in
          if newState == nil, self.viewStore.wrappedValue != nil, self.viewStore.id == id {
            self.viewStore.send(.dismiss)
          }
        }
      ),
      attachmentAnchor: self.attachmentAnchor,
      arrowEdge: self.arrowEdge
    ) { _ in
      IfLetStore(
        self.store.scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.popoverContent
      )
    }
  }
}
