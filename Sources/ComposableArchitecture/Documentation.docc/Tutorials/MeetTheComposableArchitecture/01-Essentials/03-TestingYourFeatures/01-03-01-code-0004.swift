import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testCounter() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
    
    await store.send(.incrementButtonTapped)
    await store.send(.decrementButtonTapped)
  }
}
