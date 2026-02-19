import SwiftUI

extension View {
  /// Displays an alert when the store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  @preconcurrency @MainActor
  public func alert<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    self._alert(store: store, state: { $0 }, action: { $0 })
  }

  @preconcurrency @MainActor
  func _alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $isPresented, destination in
      let alertState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.alert(
        (alertState?.title).map(Text.init) ?? Text(verbatim: ""),
        isPresented: $isPresented,
        presenting: alertState,
        actions: { alertState in
          ForEach(alertState.buttons) { button in
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
