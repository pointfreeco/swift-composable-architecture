import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testCounter() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }
}
