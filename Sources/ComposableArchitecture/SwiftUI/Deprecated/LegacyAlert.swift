import SwiftUI

@available(
  iOS,
  introduced: 13,
  deprecated: 100000,
  message: "use `View.alert(title:isPresented:presenting::actions:) instead."
)
@available(
  macOS,
  introduced: 10.15,
  deprecated: 100000,
  message: "use `View.alert(title:isPresented:presenting::actions:) instead."
)
@available(
  tvOS,
  introduced: 13,
  deprecated: 100000,
  message: "use `View.alert(title:isPresented:presenting::actions:) instead."
)
@available(
  watchOS,
  introduced: 6,
  deprecated: 100000,
  message: "use `View.alert(title:isPresented:presenting::actions:) instead."
)
extension View {
  public func legacyAlert<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    self.legacyAlert(store: store, state: { $0 }, action: { $0 })
  }

  public func legacyAlert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, _ in
      let alertState = store.state.value.wrappedValue.flatMap(toDestinationState)
      self.alert(item: $item) { _ in
        Alert(alertState!) { action in
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
