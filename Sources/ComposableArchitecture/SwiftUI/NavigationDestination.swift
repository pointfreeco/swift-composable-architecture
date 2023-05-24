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
    self.presentation(store: store) { `self`, $isPresented, destinationContent in
      self.navigationDestination(isPresented: $isPresented) {
        destinationContent(destination)
      }
    }
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
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $isPresented, destinationContent in
      self.navigationDestination(isPresented: $isPresented) {
        destinationContent(destination)
      }
    }
  }
}
