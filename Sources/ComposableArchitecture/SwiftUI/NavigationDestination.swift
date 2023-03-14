import SwiftUI

#if swift(>=5.7)
  extension View {
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func navigationDestination<State, Action, Destination: View>(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
    ) -> some View {
      self.navigationDestination(
        store: store, state: { $0 }, action: { $0 }, destination: destination
      )
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func navigationDestination<
      State, Action, DestinationState, DestinationAction, Destination: View
    >(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (State) -> DestinationState?,
      action fromDestinationAction: @escaping (DestinationAction) -> Action,
      @ViewBuilder destination destinationContent: @escaping (Store<DestinationState, DestinationAction>) -> Destination
    ) -> some View {
      self.modifier(
        PresentationModifier(
          store: store, state: toDestinationState, action: fromDestinationAction
        ) { content, $isPresented, destination in
          content.navigationDestination(isPresented: $isPresented) {
            destination { store in
              destinationContent(store)
            }
          }
        }
      )
    }
  }
#endif
