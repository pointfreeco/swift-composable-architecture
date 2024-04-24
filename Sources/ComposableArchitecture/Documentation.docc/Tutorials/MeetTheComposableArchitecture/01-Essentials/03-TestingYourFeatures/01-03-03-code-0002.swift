import ComposableArchitecture
import XCTest

@testable import CounterApp

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
  }
}
