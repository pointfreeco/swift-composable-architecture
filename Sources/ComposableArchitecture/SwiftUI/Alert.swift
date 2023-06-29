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
    self.alert(store: store, state: { $0 }, action: { $0 })
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
  public func alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $isPresented, destination in
      let alertState = store.state.value.wrappedValue.flatMap(toDestinationState)
      self.alert(
        (alertState?.title).map(Text.init) ?? Text(""),
        isPresented: $isPresented,
        presenting: alertState,
        actions: { alertState in
          ForEach(alertState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case let .send(action):
                if let action = action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case let .animatedSend(action, animation):
                if let action = action {
                  withAnimation(animation) {
                    store.send(.presented(fromDestinationAction(action)))
                  }
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init) ?? Text("")
        }
      )
    }
  }
}

extension View {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the alert is shown or dismissed.
  ///   - dismiss: An action to send when the alert is dismissed through non-user actions, such
  ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
  ///     the associated alert state.
  @ViewBuilder public func alert<Action>(
    _ store: Store<AlertState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      self.modifier(
        NewAlertModifier(
          viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
          dismiss: dismiss
        )
      )
    } else {
      self.modifier(
        OldAlertModifier(
          viewStore: ViewStore(store, removeDuplicates: { $0?.id == $1?.id }),
          dismiss: dismiss
        )
      )
    }
  }
}

// NB: Workaround for iOS 14 runtime crashes during iOS 15 availability checks.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
private struct NewAlertModifier<Action>: ViewModifier {
  @StateObject var viewStore: ViewStore<AlertState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.alert(
      (viewStore.state?.title).map { Text($0) } ?? Text(""),
      isPresented: viewStore.binding(send: dismiss).isPresent(),
      presenting: viewStore.state,
      actions: {
        ForEach($0.buttons) {
          Button($0) { action in
            if let action = action {
              viewStore.send(action)
            }
          }
        }
      },
      message: { $0.message.map { Text($0) } }
    )
  }
}

private struct OldAlertModifier<Action>: ViewModifier {
  @ObservedObject var viewStore: ViewStore<AlertState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.alert(item: viewStore.binding(send: dismiss)) { state in
      Alert(state) { action in
        if let action = action {
          viewStore.send(action)
        }
      }
    }
  }
}
