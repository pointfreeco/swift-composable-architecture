import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class EffectsBasicsTests: XCTestCase {
  func testCountUpAndDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testCountDownLessThanZero() {
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .immediate
      )
    )

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    scheduler.advance(by: .seconds(1))
    store.receive(.decrementDelayFinished) {
      $0.count = 0
    }
  }

  func testCountDownLessThanZero_CountBackUpBeforeDelayFinishes() {
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 0
    }
    scheduler.run()
  }

  func testNumberFact() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .immediate
      )
    )

    store.environment.fact.fetch = { n in Effect(value: "\(n) is a good number Brent") }

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
