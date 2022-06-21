import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class TimersTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testStart() async {
    let store = TestStore(
      initialState: TimersState(),
      reducer: timersReducer,
      environment: TimersEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    await self.scheduler.advance(by: 1)
    await store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    await self.scheduler.advance(by: 5)
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
    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
    await store.finish()
  }
}
