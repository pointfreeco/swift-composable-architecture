import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class AlertsAndConfirmationDialogsTests: XCTestCase {
  func testAlert() async {
    let store = TestStore(
      initialState: AlertAndConfirmationDialog.State(),
      reducer: AlertAndConfirmationDialog()
    )

    await store.send(.alertButtonTapped) {
      $0.alert = AlertState {
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
    }
    await store.send(.incrementButtonTapped) {
      $0.alert = AlertState { TextState("Incremented!") }
      $0.count = 1
    }
    await store.send(.alertDismissed) {
      $0.alert = nil
    }
  }

  func testConfirmationDialog() async {
    let store = TestStore(
      initialState: AlertAndConfirmationDialog.State(),
      reducer: AlertAndConfirmationDialog()
    )

    await store.send(.confirmationDialogButtonTapped) {
      $0.confirmationDialog = ConfirmationDialogState {
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
    }
    await store.send(.incrementButtonTapped) {
      $0.alert = AlertState { TextState("Incremented!") }
      $0.count = 1
    }
    await store.send(.confirmationDialogDismissed) {
      $0.confirmationDialog = nil
    }
  }
}
