import Combine
import ComposableArchitecture
import SwiftUI
import XCTest

@testable import SwiftUICaseStudies

class AlertsAndActionSheetsTests: XCTestCase {
  func testAlert() {
    let store = TestStore(
      initialState: AlertAndSheetState(),
      reducer: AlertAndSheetReducer,
      environment: AlertAndSheetEnvironment()
    )

    store.assert(
      .send(.alertButtonTapped) {
        $0.alert = .show(
          .init(
            message: "This is an alert",
            primaryButton: .init(
              action: .alertCancelTapped,
              label: "Cancel",
              type: .cancel
            ),
            secondaryButton: .init(
              action: .incrementButtonTapped,
              label: "Increment"
            ),
            title: "Alert!"
          )
        )
      },
      .send(.incrementButtonTapped) {
        $0.alert = .dismissed
        $0.count = 1
      }
    )
  }

  func testActionSheet() {
    let store = TestStore(
      initialState: AlertAndSheetState(),
      reducer: AlertAndSheetReducer,
      environment: AlertAndSheetEnvironment()
    )

    store.assert(
      .send(.actionSheetButtonTapped) {
        $0.actionSheet = .show(
          .init(
            buttons: [
              .init(
                action: .actionSheetCancelTapped,
                label: "Cancel",
                type: .cancel
              ),
              .init(
                action: .incrementButtonTapped,
                label: "Increment"
              ),
              .init(
                action: .decrementButtonTapped,
                label: "Decrement"
              ),
            ],
            message: "This is an action sheet.",
            title: "Action sheet"
          )
        )
      },
      .send(.incrementButtonTapped) {
        $0.actionSheet = .dismissed
        $0.count = 1
      }
    )
  }
}
