import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class TimersTests: XCTestCase {
  func testStart() async {
    let store = TestStore(
      initialState: Timers.State(),
      reducer: Timers()
    )

    let clock = TestClock()
    store.dependencies.continuousClock = clock

    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    await clock.advance(by: .seconds(5))
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 2
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 3
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 4
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 5
    }
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 6
    }
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
  }
}
