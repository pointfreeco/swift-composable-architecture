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
          title: "Alert!",
          message: "This is an alert",
          primaryButton: .cancel(),
          secondaryButton: .default("Increment", send: .incrementButtonTapped)
        )
      },
      .send(.incrementButtonTapped) {
        $0.alert = nil
        $0.count = 1
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
          title: "Action sheet",
          message: "This is an action sheet.",
          buttons: [
            .cancel(),
            .default("Increment", send: .incrementButtonTapped),
            .default("Decrement", send: .decrementButtonTapped),
          ]
        )
      },
      .send(.incrementButtonTapped) {
        $0.actionSheet = nil
        $0.count = 1
      }
    )
  }
}
