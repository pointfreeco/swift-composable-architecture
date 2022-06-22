import Combine
import ComposableArchitecture
import SwiftUI
import XCTest

@testable import SwiftUICaseStudies

class AlertsAndConfirmationDialogsTests: XCTestCase {
  func testAlert() {
    let store = TestStore(
      initialState: AlertAndConfirmationDialogState(),
      reducer: alertAndConfirmationDialogReducer,
      environment: AlertAndConfirmationDialogEnvironment()
    )

    store.send(.alertButtonTapped) {
      $0.alert = AlertState(
        title: TextState("Alert!"),
        message: TextState("This is an alert"),
        primaryButton: .cancel(TextState("Cancel")),
        secondaryButton: .default(TextState("Increment"), action: .send(.incrementButtonTapped))
      )
    }
    store.send(.incrementButtonTapped) {
      $0.alert = AlertState(title: TextState("Incremented!"))
      $0.count = 1
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
  }

  func testConfirmationDialog() {
    let store = TestStore(
      initialState: AlertAndConfirmationDialogState(),
      reducer: alertAndConfirmationDialogReducer,
      environment: AlertAndConfirmationDialogEnvironment()
    )

    store.send(.confirmationDialogButtonTapped) {
      $0.confirmationDialog = ConfirmationDialogState(
        title: TextState("Confirmation dialog"),
        message: TextState("This is a confirmation dialog."),
        buttons: [
          .cancel(TextState("Cancel")),
          .default(TextState("Increment"), action: .send(.incrementButtonTapped)),
          .default(TextState("Decrement"), action: .send(.decrementButtonTapped)),
        ]
      )
    }
    store.send(.incrementButtonTapped) {
      $0.alert = AlertState(title: TextState("Incremented!"))
      $0.count = 1
    }
    store.send(.confirmationDialogDismissed) {
      $0.confirmationDialog = nil
    }
  }
}
