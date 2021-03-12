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

    store.assert(
      .send(.alertButtonTapped) {
        $0.alert = .init(
          title: .init("Alert!"),
          message: .init("This is an alert"),
          primaryButton: .cancel(),
          secondaryButton: .default(.init("Increment"), send: .incrementButtonTapped)
        )
      },
      .send(.incrementButtonTapped) {
        $0.alert = .init(title: .init("Incremented!"))
        $0.count = 1
      },
      .send(.alertDismissed) {
        $0.alert = nil
      }
    )
  }

  func testActionSheet() {
    let store = TestStore(
      initialState: AlertAndSheetState(),
      reducer: alertAndSheetReducer,
      environment: AlertAndSheetEnvironment()
    )

    store.assert(
      .send(.actionSheetButtonTapped) {
        $0.actionSheet = .init(
          title: .init("Action sheet"),
          message: .init("This is an action sheet."),
          buttons: [
            .cancel(),
            .default(.init("Increment"), send: .incrementButtonTapped),
            .default(.init("Decrement"), send: .decrementButtonTapped),
          ]
        )
      },
      .send(.incrementButtonTapped) {
        $0.alert = .init(title: .init("Incremented!"))
        $0.count = 1
      },
      .send(.actionSheetDismissed) {
        $0.actionSheet = nil
      }
    )
  }
}
