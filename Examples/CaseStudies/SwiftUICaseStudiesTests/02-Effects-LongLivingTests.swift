import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  @MainActor
  func testReducer() async {
    let notificationCenter = NotificationCenter()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        notificationCenter: notificationCenter
      )
    )

    let task = store.send(.task)
    await task.yield()

    // Simulate a screenshot being taken
    notificationCenter.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects
    // are executed.
    notificationCenter.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  }
}
