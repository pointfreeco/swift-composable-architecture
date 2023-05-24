import SwiftUI

extension View {
  /// Presents a sheet using the given store as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `sheet` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a sheet
  ///     you create that the system displays to the user. If `store`'s state is `nil`-ed out, the
  ///     system dismisses the currently displayed sheet.
  ///   - onDismiss: The closure to execute when dismissing the modal view.
  ///   - content: A closure returning the content of the modal view.
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      self.sheet(item: $item, onDismiss: onDismiss) { _ in
        destination(content)
      }
    }
  }

  /// Presents a sheet using the given store as a data source for the sheet's content.
  ///
  /// > This is a Composable Architecture-friendly version of SwiftUI's `sheet` view modifier.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for
  ///     a modal. When `store`'s state is non-`nil`, the system passes a store of unwrapped `State`
  ///     and `Action` to the modifier's closure. You use this store to power the content in a sheet
  ///     you create that the system displays to the user. If `store`'s state is `nil`-ed out, the
  ///     system dismisses the currently displayed sheet.
  ///   - toDestinationState: A transformation to extract modal state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed modal actions into the presentation
  ///     action.
  ///   - onDismiss: The closure to execute when dismissing the modal view.
  ///   - content: A closure returning the content of the modal view.
  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, destination in
      self.sheet(item: $item, onDismiss: onDismiss) { _ in
        destination(content)
      }
    }
  }
}
