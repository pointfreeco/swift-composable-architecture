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
    await store.receive(\.factResponse, timeout: .seconds(1)) {
      $0.isLoading = false
      $0.fact = "???"
    }
  }
}
