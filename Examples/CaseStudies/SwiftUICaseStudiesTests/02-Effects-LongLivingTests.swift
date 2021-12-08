import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  @MainActor
  func testReducer() async {
    // A passthrough subject to simulate the screenshot notification
    let screenshotTaken = PassthroughSubject<Void, Never>()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        userDidTakeScreenshot: Effect(screenshotTaken)
      )
    )

    let task = store.send(.task)

    // Simulate a screenshot being taken
    screenshotTaken.send()
    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }

    task.cancel()
    await task.value

    // Simulate a screenshot being taken to show no effects
    // are executed.
//    screenshotTaken.send()
  }

  @MainActor
  func testNew() async {
    // A passthrough subject to simulate the screenshot notification
    let screenshotTaken = PassthroughSubject<Void, Never>()

    let store = MainActorTestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        userDidTakeScreenshot: Effect(screenshotTaken)
      )
    )

    let task = store.send(.task)

    // Simulate a screenshot being taken
    screenshotTaken.send()
    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 1
    }
    screenshotTaken.send()
    await store.receive(.userDidTakeScreenshotNotification) {
      $0.screenshotCount = 2
    }

    task.cancel()
    await task.value
    // await task.cancelAndFoo()
    // await task.cancel()
    // await store.cancel(task: task)
    // await store.completed(task: task)
  }
}
