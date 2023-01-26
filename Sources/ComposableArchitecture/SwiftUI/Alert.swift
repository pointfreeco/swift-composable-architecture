import SwiftUI

extension View {
  /// Displays an alert when then store's state becomes non-`nil`, and dismisses it when it becomes
  /// `nil`.
  ///
  /// - Parameters:
  ///   - store: A store that describes if the alert is shown or dismissed.
  ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
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

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
@MainActor
extension View {
  public func alert<ButtonAction>(
    store: Store<
      PresentationState<AlertState<ButtonAction>>,
      PresentationAction<AlertState<ButtonAction>, ButtonAction>
    >
  ) -> some View {
    self.alert(store: store, state: { $0 }, action: { $0 })
  }

  public func alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<State, Action>>,
    state toDestinationState: @escaping (State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (ButtonAction) -> Action
  ) -> some View {
    WithViewStore(store) {
      $0
    } removeDuplicates: {
      $0.id == $1.id
    } content: { viewStore in
      let alertState = viewStore.wrappedValue.flatMap(toDestinationState)
      return self.alert(
        (alertState?.title).map(Text.init) ?? Text(""),
        isPresented: Binding(
          get: { alertState != nil },
          set: { _ in
            if viewStore.wrappedValue.flatMap(toDestinationState) != nil {
              viewStore.send(.dismiss)
            }
          }
        ),
        presenting: alertState,
        actions: { alertState in
          ForEach(alertState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action?.type {
              case let .send(action):
                viewStore.send(.presented(fromDestinationAction(action)))
              case let .animatedSend(action, animation):
                _ = withAnimation(animation) {
                  viewStore.send(.presented(fromDestinationAction(action)))
                }
              case .none:
                viewStore.send(.dismiss)
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
