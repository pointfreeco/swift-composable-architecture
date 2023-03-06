import SwiftUI

extension View {
  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.fullScreenCover(store: store, state: { $0 }, action: { $0 }, content: content)
  }

  @available(iOS 14, tvOS 14, watchOS 7, *)
  @available(macOS, unavailable)
  public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationFullScreenCoverModifier(
        store: store,
        state: toDestinationState,
        action: fromDestinationAction,
        content: content
      )
    )
  }
}

@available(iOS 14, macCatalyst 14, tvOS 14, watchOS 7, *)
@available(macOS, unavailable)
private struct PresentationFullScreenCoverModifier<
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
  let coverContent: (Store<DestinationState, DestinationAction>) -> CoverContent

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    content coverContent: @escaping (Store<DestinationState, DestinationAction>) -> CoverContent
  ) {
    let filteredStore = store.filter { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore, observe: { $0 }, removeDuplicates: { $0.id == $1.id })
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.coverContent = coverContent
  }

  func body(content: Content) -> some View {
    content.fullScreenCover(
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
        then: self.coverContent
      )
    }
  }
}
