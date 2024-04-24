import ComposableArchitecture
import XCTest

@testable import CounterApp

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testCounter() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
  }
}
