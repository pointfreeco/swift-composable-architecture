import ComposableArchitecture
import XCTest

class AppFeatureTests: XCTestCase {
  func testIncrementInFirstTab() {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }

    await store.send(.tab1(.incrementButtonTapped))
  }
}
