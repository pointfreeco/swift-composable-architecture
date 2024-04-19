import ComposableArchitecture
import XCTest

@testable import CounterApp

@MainActor
final class AppFeatureTests: XCTestCase {
  func testIncrementInFirstTab() async {
    let store = TestStore(initialState: AppFeature.State()) {
      AppFeature()
    }
  }
}
