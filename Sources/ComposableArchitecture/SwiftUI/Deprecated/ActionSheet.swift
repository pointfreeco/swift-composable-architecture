import SwiftUI

@available(
  iOS,
  introduced: 13,
  deprecated: 100000,
  message:
    """
    use `View.confirmationDialog(title:isPresented:titleVisibility:presenting::actions:)`instead.
    """
)
@available(
  macOS,
  unavailable
)
@available(
  tvOS,
  introduced: 13,
  deprecated: 100000,
  message:
    """
    use `View.confirmationDialog(title:isPresented:titleVisibility:presenting::actions:)`instead.
    """
)
@available(
  watchOS,
  introduced: 6,
  deprecated: 100000,
  message:
    """
    use `View.confirmationDialog(title:isPresented:titleVisibility:presenting::actions:)`instead.
    """
)
extension View {
  public func actionSheet<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>, PresentationAction<ButtonAction>
    >
  ) -> some View {
    self.actionSheet(store: store, state: { $0 }, action: { $0 })
  }

  public func actionSheet<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, _ in
      let actionSheetState = store.state.value.wrappedValue.flatMap(toDestinationState)
      self.actionSheet(item: $item) { _ in
        ActionSheet(actionSheetState!) { action in
          if let action = action {
            store.send(.presented(fromDestinationAction(action)))
          } else {
            store.send(.dismiss)
          }
        }
      }
    }
  }
}
