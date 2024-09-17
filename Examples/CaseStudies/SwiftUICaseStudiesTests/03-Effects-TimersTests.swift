import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class TimersTests: XCTestCase {
  @MainActor
  func testStart() async {
    let clock = TestClock()

    let store = TestStoreOf<Timers>(initialState: Timers.State()) {
      Timers()
    } withDependencies: {
      $0.continuousClock = clock
    }

    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = true
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.private) {
      $0.secondsElapsed = 1
    }

    await clock.advance(by: .seconds(1))
    await store.receive(\.private) {
      $0.secondsElapsed = 2
    }

    await clock.advance(by: .seconds(5))
    await store.receive(\.private) {
      $0.secondsElapsed = 3
    }
    await store.receive(\.private) {
      $0.secondsElapsed = 4
    }
    await store.receive(\.private) {
      $0.secondsElapsed = 5
    }
    await store.receive(\.private) {
      $0.secondsElapsed = 6
    }
    await store.receive(\.private) {
      $0.secondsElapsed = 7
    }
    
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerActive = false
    }
  }
}
