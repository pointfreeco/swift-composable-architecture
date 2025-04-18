import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates how to best handle alerts and confirmation dialogs in the Composable \
  Architecture.

  The library comes with two types, `AlertState` and `ConfirmationDialogState`, which are data \
  descriptions of the state and actions of an alert or dialog. These types can be constructed in \
  reducers to control whether or not an alert or confirmation dialog is displayed, and \
  corresponding view modifiers, `alert(_:)` and `confirmationDialog(_:)`, can be handed bindings \
  to a store focused on an alert or dialog domain so that the alert or dialog can be displayed in \
  the view.

  The benefit of using these types is that you can get full test coverage on how a user interacts \
  with alerts and dialogs in your application
  """

@Reducer
struct AlertAndConfirmationDialog {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
    var count = 0
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case alertButtonTapped
    case confirmationDialog(PresentationAction<ConfirmationDialog>)
    case confirmationDialogButtonTapped

    @CasePathable
    enum Alert {
      case incrementButtonTapped
    }
    @CasePathable
    enum ConfirmationDialog {
      case incrementButtonTapped
      case decrementButtonTapped
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.incrementButtonTapped)),
        .confirmationDialog(.presented(.incrementButtonTapped)):
        state.alert = AlertState { TextState("Incremented!") }
        state.count += 1
        return .none

      case .alert:
        return .none

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

      case .confirmationDialog(.presented(.decrementButtonTapped)):
        state.alert = AlertState { TextState("Decremented!") }
        state.count -= 1
        return .none

      case .confirmationDialog:
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
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }
}

import UIKit
final class AlertAndConfirmationDialogViewController: UIViewController {
  @UIBindable var store: StoreOf<AlertAndConfirmationDialog>

  init(store: StoreOf<AlertAndConfirmationDialog>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let countLabel = UILabel()

    let alertButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
      self?.store.send(.alertButtonTapped)
    })
    alertButton.setTitle("Alert", for: .normal)

    let confirmationDialogButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
      self?.store.send(.confirmationDialogButtonTapped)
    })
    confirmationDialogButton.setTitle("Confirmation Dialog", for: .normal)

    let stack = UIStackView(arrangedSubviews: [
      countLabel,
      alertButton,
      confirmationDialogButton,
    ])
    stack.axis = .vertical
    stack.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.topAnchor),
      stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    observe { [weak self] in
      guard let self else { return }
      countLabel.text = "Count: \(store.count)"
    }

    present(item: $store.scope(state: \.alert, action: \.alert)) { store in
      UIAlertController(store: store)
    }
    present(
      item: $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
    ) { store in
      UIAlertController(store: store)
    }
  }
}

struct AlertAndConfirmationDialogView: View {
  @Bindable var store: StoreOf<AlertAndConfirmationDialog>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Text("Count: \(store.count)")
      Button("Alert") { store.send(.alertButtonTapped) }
      Button("Confirmation Dialog") { store.send(.confirmationDialogButtonTapped) }
    }
    .navigationTitle("Alerts & Dialogs")
    .alert($store.scope(state: \.alert, action: \.alert))
    .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
  }
}

#Preview {
  NavigationStack {
    AlertAndConfirmationDialogView(
      store: Store(initialState: AlertAndConfirmationDialog.State()) {
        AlertAndConfirmationDialog()
      }
    )
  }
}
