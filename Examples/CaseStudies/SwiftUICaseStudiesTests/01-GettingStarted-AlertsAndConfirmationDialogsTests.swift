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
      $0.alert = .init(
        title: .init("Alert!"),
        message: .init("This is an alert"),
        primaryButton: .cancel(.init("Cancel")),
        secondaryButton: .default(.init("Increment"), action: .send(.incrementButtonTapped))
      )
    }
    store.send(.incrementButtonTapped) {
      $0.alert = .init(title: .init("Incremented!"))
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
      $0.confirmationDialog = .init(
        title: .init("Confirmation dialog"),
        message: .init("This is a confirmation dialog."),
        buttons: [
          .cancel(.init("Cancel")),
          .default(.init("Increment"), action: .send(.incrementButtonTapped)),
          .default(.init("Decrement"), action: .send(.decrementButtonTapped)),
        ]
      )
    }
    store.send(.incrementButtonTapped) {
      $0.alert = .init(title: .init("Incremented!"))
      $0.count = 1
    }
    store.send(.confirmationDialogDismissed) {
      $0.confirmationDialog = nil
    }
  }
}
