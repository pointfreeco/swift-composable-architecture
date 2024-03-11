import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class EffectsBasicsTests: XCTestCase {
  @MainActor
  func testCountDown() async {
    let store = TestStore(initialState: EffectsBasics.State()) {
      EffectsBasics()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  @MainActor
  func testNumberFact() async {
    let store = TestStore(initialState: EffectsBasics.State()) {
      EffectsBasics()
    } withDependencies: {
      $0.factClient.fetch = { "\($0) is a good number Brent" }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(\.numberFactResponse.success) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }

  @MainActor
  func testDecrement() async {
    let store = TestStore(initialState: EffectsBasics.State()) {
      EffectsBasics()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    await store.receive(\.decrementDelayResponse) {
      $0.count = 0
    }
  }

  @MainActor
  func testDecrementCancellation() async {
    let store = TestStore(initialState: EffectsBasics.State()) {
      EffectsBasics()
    } withDependencies: {
      $0.continuousClock = TestClock()
    }

    await store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    await store.send(.incrementButtonTapped) {
      $0.count = 0
    }
  }
}
