import ComposableArchitecture
import XCTest

@testable import CounterApp

final class CounterFeatureTests: XCTestCase {
  func testNumberFact() async {
    let store = await TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }
  }
}
