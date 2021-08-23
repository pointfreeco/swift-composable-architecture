import Combine
import ComposableArchitecture
import SwiftUI
import XCTest

@testable import SwiftUICaseStudies

class AlertsAndActionSheetsTests: XCTestCase {
  func testAlert() {
    let store = TestStore(
      initialState: AlertAndSheetState(),
      reducer: alertAndSheetReducer,
      environment: AlertAndSheetEnvironment()
    )

    store.send(.alertButtonTapped) {
      $0.alert = .init(
        title: .init("Alert!"),
        message: .init("This is an alert"),
        primaryButton: .cancel(),
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

  func testActionSheet() {
    let store = TestStore(
      initialState: AlertAndSheetState(),
      reducer: alertAndSheetReducer,
      environment: AlertAndSheetEnvironment()
    )

    store.send(.actionSheetButtonTapped) {
      $0.actionSheet = .init(
        title: .init("Action sheet"),
        message: .init("This is an action sheet."),
        buttons: [
          .cancel(),
          .default(.init("Increment"), action: .send(.incrementButtonTapped)),
          .default(.init("Decrement"), action: .send(.decrementButtonTapped)),
        ]
      )
    }
    store.send(.incrementButtonTapped) {
      $0.alert = .init(title: .init("Incremented!"))
      $0.count = 1
    }
    store.send(.actionSheetDismissed) {
      $0.actionSheet = nil
    }
  }
}
