import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class EffectsBasicsTests: XCTestCase {
  func testCountDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        mainQueue: .immediate,
        numberFact: { _ in fatalError("Unimplemented") }
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
    store.receive(.incrementButtonTapped) {
      $0.count = 1
    }
  }

  func testNumberFact() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        mainQueue: .immediate,
        numberFact: { n in Effect(value: "\(n) is a good number Brent") }
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }
}
