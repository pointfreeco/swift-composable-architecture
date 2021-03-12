import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class LongLivingEffectsTests: XCTestCase {
  func testReducer() {
    // A passthrough subject to simulate the screenshot notification
    let screenshotTaken = PassthroughSubject<Void, Never>()

    let store = TestStore(
      initialState: .init(),
      reducer: longLivingEffectsReducer,
      environment: .init(
        userDidTakeScreenshot: Effect(screenshotTaken)
      )
    )

    store.assert(
      .send(.onAppear),

      // Simulate a screenshot being taken
      .do { screenshotTaken.send() },
      .receive(.userDidTakeScreenshotNotification) {
        $0.screenshotCount = 1
      },

      .send(.onDisappear),

      // Simulate a screenshot being taken to show no effects
      // are executed.
      .do { screenshotTaken.send() }
    )
  }
}
