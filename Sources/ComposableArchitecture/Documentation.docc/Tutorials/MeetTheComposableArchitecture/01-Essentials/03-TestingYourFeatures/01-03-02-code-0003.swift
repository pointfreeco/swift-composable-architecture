import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testTimer() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.toggleTimerButtonTapped) {
      $0.isTimerRunning = true
    }
    // ❌ An effect returned for this action is still running.
    //    It must complete before the end of the test. …
  }
}
