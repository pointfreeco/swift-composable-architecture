import SwiftUI

extension View {
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.popover(
      store: store,
      state: { $0 },
      action: { $0 },
      attachmentAnchor: attachmentAnchor,
      arrowEdge: arrowEdge,
      content: content
    )
  }

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
      PresentationPopoverModifer(
        store: store,
        state: toDestinationState,
        action: fromDestinationAction,
        attachmentAnchor: attachmentAnchor,
        arrowEdge: arrowEdge,
        content: content
      )
    )
  }
}

private struct PresentationPopoverModifer<
  State,
  Action,
  DestinationState,
  DestinationAction,
  CoverContent: View
>: ViewModifier {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let attachmentAnchor: PopoverAttachmentAnchor
  let arrowEdge: Edge
  let coverContent: (Store<DestinationState, DestinationAction>) -> CoverContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    content coverContent: @escaping (Store<DestinationState, DestinationAction>) -> CoverContent
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store.filter { state, _ in state.wrappedValue != nil },
      removeDuplicates: { $0.id == $1.id }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.attachmentAnchor = attachmentAnchor
    self.arrowEdge = arrowEdge
    self.coverContent = coverContent
  }

  func body(content: Content) -> some View {
    content.popover(
      item: self.viewStore.binding(
        get: { $0.wrappedValue.flatMap(self.toDestinationState) != nil ? $0.id : nil },
        send: .dismiss
      ),
      attachmentAnchor: self.attachmentAnchor,
      arrowEdge: self.arrowEdge
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
