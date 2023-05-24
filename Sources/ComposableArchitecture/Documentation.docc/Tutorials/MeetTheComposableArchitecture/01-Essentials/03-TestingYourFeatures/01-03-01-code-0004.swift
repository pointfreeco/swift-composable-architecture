import ComposableArchitecture
import XCTest

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testCounter() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.incrementButtonTapped)
    // 🛑 State was not expected to change, but a change occurred: …
    //
    //       CounterFeature.State(
    //     −   count: 0,
    //     +   count: 1,
    //         fact: nil,
    //         isLoading: false,
    //         isTimerRunning: false
    //       )
    //
    // (Expected: −, Actual: +)
    await store.send(.decrementButtonTapped)
    // 🛑 State was not expected to change, but a change occurred: …
    //
    //       CounterFeature.State(
    //     −   count: 1,
    //     +   count: 0,
    //         fact: nil,
    //         isLoading: false,
    //         isTimerRunning: false
    //       )
    //
    // (Expected: −, Actual: +)
  }
}
