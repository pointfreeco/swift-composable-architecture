import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  @MainActor
  func testReducer() async {
    var continuation: AsyncStream<Void>.Continuation!
    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        screenshots: .init { continuation = $0 }, notificationCenter: .default
      )
    )

    let task = store.send(.task)
//    await task.yield()

    // Simulate a screenshot being taken
    continuation.yield()
//    NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects
    // are executed.
    continuation.yield()
//    NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  }
}
