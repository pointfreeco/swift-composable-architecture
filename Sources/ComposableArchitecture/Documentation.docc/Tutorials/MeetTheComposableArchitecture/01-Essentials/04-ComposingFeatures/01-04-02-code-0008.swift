import ComposableArchitecture
import XCTest

@testable import CounterApp

@MainActor
final class AppFeatureTests: XCTestCase {
  func testIncrementInFirstTab() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }
    
    await store.send(\.tab1.incrementButtonTapped) {
      $0.tab1.count = 1
    }
  }
}
