import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

import SwiftUI

@MainActor
class EffectsBasicsTests: XCTestCase {
  func testCountUpAndDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testNumberFact_HappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing
      )
    )

    store.environment.fact.fetchAsync = { n in "\(n) is a good number Brent" }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.success("2 is a good number Brent"))) {
       $0.isNumberFactRequestInFlight = false
      $0.numberFact = "2 is a good number Brent"
    }
  }

  func testNumberFact_Failing() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing
      )
    )

    store.environment.fact.fetch = { _ in .init(error: .init()) }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    store.receive(.numberFactResponse(.failure(.init()))) {
      $0.isNumberFactRequestInFlight = false
    }
  }
}
