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
      @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) ->
        Destination
    ) -> some View {
      self.modifier(
        PresentationNavigationDestinationModifier(
          store: store,
          state: toDestinationState,
          action: fromDestinationAction,
          content: destination
        )
      )
    }
  }

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  private struct PresentationNavigationDestinationModifier<
    State,
    Action,
    DestinationState,
    DestinationAction,
    CoverContent: View
  >: ViewModifier {
    let store: Store<PresentationState<State>, PresentationAction<Action>>
    @StateObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
    let toDestinationState: (State) -> DestinationState?
    let fromDestinationAction: (DestinationAction) -> Action
    let coverContent: (Store<DestinationState, DestinationAction>) -> CoverContent

    init(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (State) -> DestinationState?,
      action fromDestinationAction: @escaping (DestinationAction) -> Action,
      content coverContent: @escaping (Store<DestinationState, DestinationAction>) -> CoverContent
    ) {
      self.store = store
      self._viewStore = StateObject(
        wrappedValue: ViewStore(
          store
            .filter { state, _ in state.wrappedValue != nil }
            .scope(state: { $0.wrappedValue.flatMap(toDestinationState) != nil })
        )
      )
      self.toDestinationState = toDestinationState
      self.fromDestinationAction = fromDestinationAction
      self.coverContent = coverContent
    }

    func body(content: Content) -> some View {
      content.navigationDestination(isPresented: self.viewStore.binding(send: .dismiss)) {
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
#endif
