import SwiftUI

extension View {
  /// Displays an action sheet when the store's state becomes non-`nil`, and dismisses it when it
  /// becomes `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  ///   - toDestinationState: A transformation to extract alert state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed alert actions into the presentation
  ///     action.
  @available(
    iOS,
    introduced: 13,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:)' instead."
  )
  @available(macOS, unavailable)
  @available(
    tvOS,
    introduced: 13,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:)' instead."
  )
  @available(
    watchOS,
    introduced: 6,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:)' instead."
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public func actionSheet<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>, PresentationAction<ButtonAction>
    >
  ) -> some View {
    self.actionSheet(store: store, state: { $0 }, action: { $0 })
  }

  /// Displays an alert when the store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  ///   - toDestinationState: A transformation to extract alert state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed alert actions into the presentation
  ///     action.
  @available(
    iOS,
    introduced: 13,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:state:action:)' instead."
  )
  @available(macOS, unavailable)
  @available(
    tvOS,
    introduced: 13,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:state:action:)' instead."
  )
  @available(
    watchOS,
    introduced: 6,
    deprecated: 100000,
    message: "use 'View.confirmationDialog(store:state:action:)' instead."
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public func actionSheet<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, _ in
      let actionSheetState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.actionSheet(item: $item) { _ in
        ActionSheet(actionSheetState!) { action in
          if let action {
            store.send(.presented(fromDestinationAction(action)))
          } else {
            store.send(.dismiss)
          }
        }
      }
    }
  }
}
