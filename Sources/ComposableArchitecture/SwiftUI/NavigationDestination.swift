#if swift(>=5.7)
  import SwiftUI

  extension View {
    /// Associates a destination view with a store that can be used to push the view onto a
    /// `NavigationStack`.
    ///
    /// > This is a Composable Architecture-friendly version of SwiftUI's
    /// > `navigationDestination(isPresented:)` view modifier.
    ///
    /// - Parameters:
    ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
    ///     a screen. When `store`'s state is non-`nil`, the system passes a store of unwrapped
    ///     `State` and `Action` to the modifier's closure. You use this store to power the content
    ///     in a view that the system pushes onto the navigation stack. If `store`'s state is
    ///     `nil`-ed out, the system pops the view from the stack.
    ///   - destination: A closure returning the content of the destination view.
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    public func navigationDestination<State, Action, Destination: View>(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
    ) -> some View {
      self.navigationDestination(
        store: store, state: { $0 }, action: { $0 }, destination: destination
      )
    }

    /// Associates a destination view with a store that can be used to push the view onto a
    /// `NavigationStack`.
    ///
    /// > This is a Composable Architecture-friendly version of SwiftUI's
    /// > `navigationDestination(isPresented:)` view modifier.
    ///
    /// - Parameters:
    ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
    ///     a screen. When `store`'s state is non-`nil`, the system passes a store of unwrapped
    ///     `State` and `Action` to the modifier's closure. You use this store to power the content
    ///     in a view that the system pushes onto the navigation stack. If `store`'s state is
    ///     `nil`-ed out, the system pops the view from the stack.
    ///   - toDestinationState: A transformation to extract screen state from the presentation
    ///     state.
    ///   - fromDestinationAction: A transformation to embed screen actions into the presentation
    ///     action.
    ///   - destination: A closure returning the content of the destination view.
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
    DestinationContent: View
  >: ViewModifier {
    let store: Store<PresentationState<State>, PresentationAction<Action>>
    @StateObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
    let toDestinationState: (State) -> DestinationState?
    let fromDestinationAction: (DestinationAction) -> Action
    let destinationContent: (Store<DestinationState, DestinationAction>) -> DestinationContent

    init(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (State) -> DestinationState?,
      action fromDestinationAction: @escaping (DestinationAction) -> Action,
      content destinationContent:
        @escaping (Store<DestinationState, DestinationAction>) -> DestinationContent
    ) {
      let filteredStore =
        store
        .invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
        .filterSend { state, _ in
          state.wrappedValue.flatMap(toDestinationState) == nil ? !BindingLocal.isActive : true
        }
      self.store = filteredStore
      self._viewStore = StateObject(
        wrappedValue: ViewStore(
          filteredStore.scope(
            state: { $0.wrappedValue.flatMap(toDestinationState) != nil },
            action: { $0 }
          ),
          observe: { $0 }
        )
      )
      self.toDestinationState = toDestinationState
      self.fromDestinationAction = fromDestinationAction
      self.destinationContent = destinationContent
    }

    func body(content: Content) -> some View {
      content.navigationDestination(
        isPresented: self.viewStore.binding(send: .dismiss)
      ) {
        IfLetStore(
          self.store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
            action: { .presented(self.fromDestinationAction($0)) }
          ),
          then: self.destinationContent
        )
      }
    }
  }
#endif
