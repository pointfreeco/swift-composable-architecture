import ComposableArchitecture
import XCTest

@testable import CounterApp

final class AppFeatureTests: XCTestCase {
  func testIncrementInFirstTab() async {
    let store = await TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }
    
    await store.send(\.tab1.incrementButtonTapped)
  }
}
