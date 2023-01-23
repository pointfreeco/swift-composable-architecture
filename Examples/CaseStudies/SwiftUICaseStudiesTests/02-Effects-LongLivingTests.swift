import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class LongLivingEffectsTests: XCTestCase {
  func testReducer() async {
    let (screenshots, takeScreenshot) = AsyncStream<Void>.streamWithContinuation()

    let store = TestStore(
      initialState: LongLivingEffects.State(),
      reducer: LongLivingEffects()
    ) {
      $0.screenshots = { screenshots }
    }

    let task = await store.send(.task)

    // Simulate a screenshot being taken
    takeScreenshot.yield()

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects are executed.
    takeScreenshot.yield()
  }
}
