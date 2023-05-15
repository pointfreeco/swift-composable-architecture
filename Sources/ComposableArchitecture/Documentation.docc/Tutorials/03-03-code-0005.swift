import ComposableArchitecture
import XCTest

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(.factResponse("???"), timeout: .seconds(1)) {
      $0.isLoading = false
      $0.fact = "???"
    }
    // 🛑 A state change does not match expectation: …
    //
    //       CounterFeature.State(
    //         count: 0,
    //     −   fact: "???",
    //     +   fact: "0 is the atomic number of the theoretical element tetraneutron.",
    //         isLoading: false,
    //         isTimerRunning: false
    //       )
  }
}
