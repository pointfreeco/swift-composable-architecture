import SwiftUI

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension View {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  public func alert<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    self._alert(store: store, state: { $0 }, action: { $0 })
  }

  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  ///   - toDestinationState: A transformation to extract alert state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed alert actions into the presentation
  ///     action.
  @available(
    iOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  public func alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self._alert(store: store, state: toDestinationState, action: fromDestinationAction)
  }

  private func _alert<State, Action, ButtonAction>(
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
              case let .send(action):
                if let action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case let .animatedSend(action, animation):
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
