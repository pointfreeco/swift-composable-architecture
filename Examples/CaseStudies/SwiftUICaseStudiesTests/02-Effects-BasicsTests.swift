import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class EffectsBasicsTests: XCTestCase {
  func testCountUpAndDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testNumberFact_HappyPath() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

//    store.environment.fact.fetch = { Effect(value: "\($0) is a good number Brent") }
    store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }
    store.environment.mainQueue = .immediate

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
    store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }

  func testNumberFact_UnhappyPath() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

//    store.environment.fact.fetch = { _ in Effect(error: FactClient.Failure()) }
    store.environment.fact.fetchAsync = { _ in throw FactClient.Failure() }
    store.environment.mainQueue = .immediate

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.02)
    store.receive(.numberFactResponse(.failure(FactClient.Failure()))) {
      $0.isNumberFactRequestInFlight = false
    }
  }
}

extension EffectsBasicsEnvironment {
  static let unimplemented = Self(
    fact: .unimplemented,
    mainQueue: .unimplemented
  )
}
