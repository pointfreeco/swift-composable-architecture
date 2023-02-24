import SwiftUI

// TODO: Support deprecated `NavigationLink` APIs

// TODO: Do we want this alternative to `IfLetStore`? Should it be an `IfLetStore.init` overload?
public struct PresentationStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Dismissed: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let dismissed: Dismissed

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder dismissed: () -> Dismissed
  ) {
    self.store = store
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.destination = destination
    self.dismissed = dismissed()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination,
    @ViewBuilder dismissed: () -> Dismissed
  ) where State == DestinationState, Action == DestinationAction {
    self.store = store
    self.toDestinationState = { $0 }
    self.fromDestinationAction = { $0 }
    self.destination = destination
    self.dismissed = dismissed()
  }

  public var body: some View {
    IfLetStore(
      self.store.scope(
        state: { $0.wrappedValue.flatMap(toDestinationState) },
        action: { .presented(fromDestinationAction($0)) }
      )
    ) { store in
      self.destination(store)
    } else: {
      self.dismissed
    }
  }
}
