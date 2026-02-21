import SwiftUI

extension View {
  /// Displays a dialog when the store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for a
  ///     dialog.
  @preconcurrency @MainActor
  public func confirmationDialog<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>,
      PresentationAction<ButtonAction>
    >
  ) -> some View {
    self._confirmationDialog(store: store, state: { $0 }, action: { $0 })
  }

  @preconcurrency @MainActor
  func _confirmationDialog<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ confirmationDialogAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $isPresented, destination in
      let confirmationDialogState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.confirmationDialog(
        (confirmationDialogState?.title).map(Text.init) ?? Text(verbatim: ""),
        isPresented: $isPresented,
        titleVisibility: (confirmationDialogState?.titleVisibility).map(Visibility.init)
          ?? .automatic,
        presenting: confirmationDialogState,
        actions: { confirmationDialogState in
          ForEach(confirmationDialogState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case .send(let action):
                if let action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case .animatedSend(let action, let animation):
                if let action {
                  store.send(.presented(fromDestinationAction(action)), animation: animation)
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init)
        }
      )
    }
  }
}
