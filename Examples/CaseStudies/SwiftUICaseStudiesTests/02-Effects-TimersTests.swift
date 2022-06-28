import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class TimersTests: XCTestCase {
  func testStart() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: TimersState(),
      reducer: timersReducer,
      environment: TimersEnvironment(
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    mainQueue.advance(by: 1)
    store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    mainQueue.advance(by: 5)
    store.receive(.timerTicked) {
      $0.secondsElapsed = 2
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 3
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 4
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 5
    }
    store.receive(.timerTicked) {
      $0.secondsElapsed = 6
    }
    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
  }
}
