import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  @MainActor
  func testReducer() async {
    var continuation: AsyncStream<Void>.Continuation!
    let s = AsyncStream<Void> { continuation = $0 }
    let c = continuation!

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        screenshots: { s },
        notificationCenter: .default
      )
    )

    var task = store.send(.task)

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

    let s1 = AsyncStream<Void> { continuation = $0 }
    let c1 = continuation!
    store.environment.screenshots = { s1 }

    
    task = store.send(.task)
    c1.yield()
    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 2
    }


    await task.cancel()
  }
}
