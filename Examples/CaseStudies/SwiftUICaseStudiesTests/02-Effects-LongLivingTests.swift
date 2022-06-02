import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  func testReducer() {
    let notificationCenter = NotificationCenter()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        notificationCenter: notificationCenter
      )
    )

    store.send(.onAppear)

    // Simulate a screenshot being taken
    notificationCenter.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    store.send(.onDisappear)

    // Simulate a screenshot being taken to show no effects
    // are executed.
    notificationCenter.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  }
}
