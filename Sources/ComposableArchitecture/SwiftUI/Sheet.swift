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
    @ViewBuilder content destinationContent: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.modifier(
      PresentationModifier(
        store: store, state: toDestinationState, action: fromDestinationAction
      ) { content, $item, destination in
        content.sheet(item: $item) { _ in
          destination { store in
            destinationContent(store)
          }
        }
      }
    )
  }
}
