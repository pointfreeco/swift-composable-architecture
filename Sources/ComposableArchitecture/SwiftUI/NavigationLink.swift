import SwiftUI

@available(iOS, introduced: 13.0, deprecated: 16.0)
@available(macOS, introduced: 10.15, deprecated: 13.0)
@available(tvOS, introduced: 13.0, deprecated: 16.0)
@available(watchOS, introduced: 6.0, deprecated: 9.0)
public struct NavigationLinkStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Label: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let label: Label

  init(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder label: () -> Label
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store
        .filter { state, _ in state.wrappedValue != nil }
        .scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.destination = destination
    self.label = label()
  }

  public var body: some View {
    NavigationLink(
      isActive: self.viewStore.binding(send: .dismiss)
    ) {
      IfLetStore(
        self.store.scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.destination
      )
    } label: {
      self.label
    }
  }
}
