import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    // ❌ An effect returned for this action is still running.
    //    It must complete before the end of the test. …
  }
}
