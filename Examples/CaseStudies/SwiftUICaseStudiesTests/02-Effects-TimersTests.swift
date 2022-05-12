import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class TimersTests: XCTestCase {
  let mainQueue = DispatchQueue.test

  func testStart() {
    let store = _TestStore(
      initialState: TimersState(),
      reducer: TimersReducer()
        .dependency(\.mainQueue, self.mainQueue.eraseToAnyScheduler())
    )

    store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }
    self.mainQueue.advance(by: 1)
    store.receive(.timerTicked) {
      $0.secondsElapsed = 1
    }
    self.mainQueue.advance(by: 5)
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
