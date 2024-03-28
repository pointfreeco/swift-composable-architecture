import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class AlertsAndConfirmationDialogsTests: XCTestCase {
  @MainActor
  func testAlert() async {
    let store = TestStore(initialState: AlertsAndConfirmationDialogs.State()) {
      AlertsAndConfirmationDialogs()
    }

    await store.send(.alertButtonTapped) {
      $0.destination = .increment(.init())
    }
    await store.send(\.destination.presented.increment.incrementButtonTapped) {
      $0.destination = .notice(.init(title: "Incremented!"))
      $0.count = 1
    }
    await store.send(\.destination.presented.notice.okButtonTapped) {
      $0.destination = nil
    }
  }

  @MainActor
  func testConfirmationDialog() async {
    let store = TestStore(initialState: AlertsAndConfirmationDialogs.State()) {
      AlertsAndConfirmationDialogs()
    }

    await store.send(.confirmationDialogButtonTapped) {
      $0.destination = .incrementOrDecrement(.init())
    }
    await store.send(\.destination.presented.incrementOrDecrement.incrementButtonTapped) {
      $0.destination = .notice(.init(title: "Incremented!"))
      $0.count = 1
    }
    await store.send(\.destination.presented.notice.okButtonTapped) {
      $0.destination = nil
    }
    
    await store.send(.confirmationDialogButtonTapped) {
      $0.destination = .incrementOrDecrement(.init())
    }
    await store.send(\.destination.presented.incrementOrDecrement.decrementButtonTapped) {
      $0.destination = .notice(.init(title: "Decremented!"))
      $0.count = 0
    }
    await store.send(\.destination.presented.notice.okButtonTapped) {
      $0.destination = nil
    }

  }
}
