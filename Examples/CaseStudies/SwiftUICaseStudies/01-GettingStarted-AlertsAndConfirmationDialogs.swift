import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to best handle alerts and confirmation dialogs in the Composable \
  Architecture.

  Because the library demands that all data flow through the application in a single direction, we \
  cannot leverage SwiftUI's two-way bindings because they can make changes to state without going \
  through a reducer. This means we can't directly use the standard API to display alerts and sheets.

  However, the library comes with two types, `AlertState` and `ConfirmationDialogState`, which can \
  be constructed from reducers and control whether or not an alert or confirmation dialog is \
  displayed. Further, it automatically handles sending actions when you tap their buttons, which \
  allows you to properly handle their functionality in the reducer rather than in two-way bindings \
  and action closures.

  The benefit of doing this is that you can get full test coverage on how a user interacts with \
  alerts and dialogs in your application
  """

struct AlertAndConfirmationDialogState: Equatable {
  var alert: AlertState<AlertAndConfirmationDialogAction>?
  var confirmationDialog: ConfirmationDialogState<AlertAndConfirmationDialogAction>?
  var count = 0
}

enum AlertAndConfirmationDialogAction: Equatable {
  case alertButtonTapped
  case alertDismissed
  case confirmationDialogButtonTapped
  case confirmationDialogDismissed
  case decrementButtonTapped
  case incrementButtonTapped
}

struct AlertAndConfirmationDialogEnvironment {}

let alertAndConfirmationDialogReducer = Reducer<
  AlertAndConfirmationDialogState, AlertAndConfirmationDialogAction,
  AlertAndConfirmationDialogEnvironment
> { state, action, _ in

  switch action {
  case .alertButtonTapped:
    state.alert = AlertState(
      title: TextState("Alert!"),
      message: TextState("This is an alert"),
      primaryButton: .cancel(TextState("Cancel")),
      secondaryButton: .default(TextState("Increment"), action: .send(.incrementButtonTapped))
    )
    return .none

  case .alertDismissed:
    state.alert = nil
    return .none

  case .confirmationDialogButtonTapped:
    state.confirmationDialog = ConfirmationDialogState(
      title: TextState("Confirmation dialog"),
      message: TextState("This is a confirmation dialog."),
      buttons: [
        .cancel(TextState("Cancel")),
        .default(TextState("Increment"), action: .send(.incrementButtonTapped)),
        .default(TextState("Decrement"), action: .send(.decrementButtonTapped)),
      ]
    )
    return .none

  case .confirmationDialogDismissed:
    state.confirmationDialog = nil
    return .none

  case .decrementButtonTapped:
    state.alert = AlertState(title: TextState("Decremented!"))
    state.count -= 1
    return .none

  case .incrementButtonTapped:
    state.alert = AlertState(title: TextState("Incremented!"))
    state.count += 1
    return .none
  }
}

struct AlertAndConfirmationDialogView: View {
  let store: Store<AlertAndConfirmationDialogState, AlertAndConfirmationDialogAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Text("Count: \(viewStore.count)")
        Button("Alert") { viewStore.send(.alertButtonTapped) }
        Button("Confirmation Dialog") { viewStore.send(.confirmationDialogButtonTapped) }
      }
    }
    .navigationTitle("Alerts & Dialogs")
    .alert(
      self.store.scope(state: \.alert),
      dismiss: .alertDismissed
    )
    .confirmationDialog(
      self.store.scope(state: \.confirmationDialog),
      dismiss: .confirmationDialogDismissed
    )
  }
}

struct AlertAndConfirmationDialog_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AlertAndConfirmationDialogView(
        store: Store(
          initialState: AlertAndConfirmationDialogState(),
          reducer: alertAndConfirmationDialogReducer,
          environment: AlertAndConfirmationDialogEnvironment()
        )
      )
    }
  }
}
