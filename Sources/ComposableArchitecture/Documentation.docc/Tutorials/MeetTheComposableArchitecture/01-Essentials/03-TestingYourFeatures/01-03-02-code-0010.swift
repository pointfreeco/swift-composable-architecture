import ComposableArchitecture
import XCTest

@testable import CounterApp

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testTimer() async {
    let clock = TestClock()
    
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }
    
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = true
    }
    await clock.advance(by: .seconds(1))
    await store.receive(\.timerTick) {
      $0.count = 1
    }
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = false
    }
  }
}
