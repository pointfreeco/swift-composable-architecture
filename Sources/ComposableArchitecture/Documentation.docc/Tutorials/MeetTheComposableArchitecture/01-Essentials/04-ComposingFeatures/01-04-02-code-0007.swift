import ComposableArchitecture
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
  func testIncrementInFirstTab() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }
    
    await store.send(.tab1(.incrementButtonTapped))
  }
}
