import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class EffectsBasicsTests: XCTestCase {
  func testCountDown() async {
    let store = TestStore(
      initialState: EffectsBasics.State(),
      reducer: EffectsBasics()
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
    await store.receive(.incrementButtonTapped) {
      $0.count = 1
    }
  }

  func testNumberFact() async {
    let store = TestStore(
      initialState: EffectsBasics.State(),
      reducer: EffectsBasics()
        .dependency(\.factClient.fetch) { "\($0) is a good number Brent" }
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }
}
