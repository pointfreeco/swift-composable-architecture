import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class AlertsAndConfirmationDialogsTests: XCTestCase {
  func testAlert() async {
    let store = await TestStore(initialState: AlertAndConfirmationDialog.State()) {
      AlertAndConfirmationDialog()
    }

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
    await store.send(\.alert.incrementButtonTapped) {
      $0.alert = AlertState { TextState("Incremented!") }
      $0.count = 1
    }
    await store.send(\.alert.dismiss) {
      $0.alert = nil
    }
  }

  func testConfirmationDialog() async {
    let store = await TestStore(initialState: AlertAndConfirmationDialog.State()) {
      AlertAndConfirmationDialog()
    }

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
    await store.send(\.confirmationDialog.incrementButtonTapped) {
      $0.alert = AlertState { TextState("Incremented!") }
      $0.confirmationDialog = nil
      $0.count = 1
    }
  }
}
