import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  @MainActor
  func testReducer() async {
    var (screenshots, takeScreenshot) = AsyncStream<Void>.pipe()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        screenshots: { screenshots },
        notificationCenter: .default
      )
    )

    var task = store.send(.task)

    // Simulate a screenshot being taken
    takeScreenshot.yield()

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    // Simulate screen going away
    await task.cancel()

    // Simulate a screenshot being taken to show no effects
    // are executed.
    takeScreenshot.yield()

    (screenshots, takeScreenshot) = AsyncStream<Void>.pipe()
    store.environment.screenshots = { screenshots }
    
    task = store.send(.task)

    // Simulate a screenshot being taken
    takeScreenshot.yield()

    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 2
    }

    await task.cancel()
  }
}
