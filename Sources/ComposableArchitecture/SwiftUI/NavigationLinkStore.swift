import SwiftUI

@available(iOS, introduced: 13, deprecated: 16)
@available(macOS, introduced: 10.15, deprecated: 13)
@available(tvOS, introduced: 13, deprecated: 16)
@available(watchOS, introduced: 6, deprecated: 9)
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
  let onTap: () -> Void
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let label: Label
  var isDetailLink = true

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction {
    let filteredStore = store.filterSend { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(
      filteredStore.scope(
        state: { $0.wrappedValue != nil },
        action: { $0 }
      )
    )
    self.toDestinationState = { $0 }
    self.fromDestinationAction = { $0 }
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder label: () -> Label
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store
        .filterSend { state, _ in state.wrappedValue != nil }
        .scope(
          state: { $0.wrappedValue.flatMap(toDestinationState) != nil },
          action: { $0 }
        )
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    id: State.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction, State: Identifiable {
    let filteredStore = store.filterSend { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(
      filteredStore.scope(
        state: { $0.wrappedValue?.id == id },
        action: { $0 }
      )
    )
    self.toDestinationState = { $0 }
    self.fromDestinationAction = { $0 }
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    id: DestinationState.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where DestinationState: Identifiable {
    self.store = store
    self.viewStore = ViewStore(
      store
        .filterSend { state, _ in state.wrappedValue != nil }
        .scope(
          state: { $0.wrappedValue.flatMap(toDestinationState)?.id == id },
          action: { $0 }
        )
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public var body: some View {
    NavigationLink(
      isActive: Binding(
        get: { self.viewStore.state },
        set: {
          if $0 {
            self.onTap()
          } else if self.viewStore.state {
            self.viewStore.send(.dismiss)
          }
        }
      )
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
    #if os(iOS)
      .isDetailLink(self.isDetailLink)
    #endif
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func isDetailLink(_ isDetailLink: Bool) -> Self {
    var link = self
    link.isDetailLink = isDetailLink
    return link
  }
}
