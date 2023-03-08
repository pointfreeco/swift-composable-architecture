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
  let onTap: () -> Void
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let label: Label

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction {
    let filteredStore = store.filter { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore.scope(state: { $0.wrappedValue != nil }))
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
        .filter { state, _ in state.wrappedValue != nil }
        .scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
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
    let filteredStore = store.filter { state, _ in state.wrappedValue != nil }
    self.store = filteredStore
    self.viewStore = ViewStore(filteredStore.scope(state: { $0.wrappedValue?.id == id }))
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
        .filter { state, _ in state.wrappedValue != nil }
        .scope(state: { $0.wrappedValue.flatMap(toDestinationState)?.id == id })
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public var body: some View {
    NavigationLink(
      // TODO: construct better binding that handles animation
      isActive: Binding(
        get: { self.viewStore.state },
        set: {
          if $0 {
            self.onTap()
          } else {
            self.viewStore.send(.dismiss)
          }
        }
      )
    ) {
      IfLetStore(
        self.store,
        state: returningLastNonNilValue(self.toDestinationState),
        action: self.fromDestinationAction,
        then: self.destination
      )
    } label: {
      self.label
    }
  }
}
