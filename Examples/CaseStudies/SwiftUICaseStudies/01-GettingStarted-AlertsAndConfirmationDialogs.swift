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

// MARK: - Feature domain

struct AlertAndConfirmationDialog: ReducerProtocol {
  struct State: Equatable {
    var alert: AlertState<Action>?
    var confirmationDialog: ConfirmationDialogState<Action>?
    var count = 0
  }

  enum Action: Equatable {
    case alertButtonTapped
    case alertDismissed
    case confirmationDialogButtonTapped
    case confirmationDialogDismissed
    case decrementButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .alertButtonTapped:
      state.alert = AlertState {
        TextState("Alert!")
      } actions: {
        ButtonState(role: .cancel) {
          TextState("Cancel")
        }
        ButtonState(action: .incrementButtonTapped) {
          TextState("Increment")
        }
      } message: {
        TextState("This is an alert")
      }
      return .none

    case .alertDismissed:
      state.alert = nil
      return .none

    case .confirmationDialogButtonTapped:
      state.confirmationDialog = ConfirmationDialogState {
        TextState("Confirmation dialog")
      } actions: {
        ButtonState(role: .cancel) {
          TextState("Cancel")
        }
        ButtonState(action: .incrementButtonTapped) {
          TextState("Increment")
        }
        ButtonState(action: .decrementButtonTapped) {
          TextState("Decrement")
        }
      } message: {
        TextState("This is a confirmation dialog.")
      }
      return .none

    case .confirmationDialogDismissed:
      state.confirmationDialog = nil
      return .none

    case .decrementButtonTapped:
      state.alert = AlertState { TextState("Decremented!") }
      state.count -= 1
      return .none

    case .incrementButtonTapped:
      state.alert = AlertState { TextState("Incremented!") }
      state.count += 1
      return .none
    }
  }
}

// MARK: - Feature view

struct AlertAndConfirmationDialogView: View {
  let store: StoreOf<AlertAndConfirmationDialog>

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
      self.store.scope(state: \.alert, action: { $0 }),
      dismiss: .alertDismissed
    )
    .confirmationDialog(
      self.store.scope(state: \.confirmationDialog, action: { $0 }),
      dismiss: .confirmationDialogDismissed
    )
  }
}

// MARK: - SwiftUI previews

struct AlertAndConfirmationDialog_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AlertAndConfirmationDialogView(
        store: Store(initialState: AlertAndConfirmationDialog.State()) {
          AlertAndConfirmationDialog()
        }
      )
    }
  }
}
