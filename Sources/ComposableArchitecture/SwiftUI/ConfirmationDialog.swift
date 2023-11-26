import SwiftUI

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension View {
  /// Displays a dialog when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for a
  ///     dialog.
  public func confirmationDialog<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>,
      PresentationAction<ButtonAction>
    >
  ) -> some View {
    self._confirmationDialog(store: store, state: { $0 }, action: { $0 })
  }

  /// Displays a dialog when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for a
  ///     dialog.
  ///   - toDestinationState: A transformation to extract dialog state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed dialog actions into the presentation
  ///     action.
  @available(
    iOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  public func confirmationDialog<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ confirmationDialogAction: ButtonAction) -> Action
  ) -> some View {
    self._confirmationDialog(store: store, state: toDestinationState, action: fromDestinationAction)
  }

  private func _confirmationDialog<State, Action, ButtonAction>(
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
              case let .send(action):
                if let action = action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case let .animatedSend(action, animation):
                if let action = action {
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
