import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
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

  func testNumberFact_HappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

//    store.environment.fact.fetch = { Effect(value: "\($0) is a good number Brent") }
    store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }
//    store.environment.mainQueue = .immediate

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
//    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
    await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }

//    _ = { store.receive(.decrementButtonTapped) }()
  }

  func testNumberFact_UnhappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: .unimplemented
    )

    struct SomeError: Equatable, Error {}
//    store.environment.fact.fetch = { _ in Effect(error: FactClient.Failure()) }
    store.environment.fact.fetchAsync = { _ in throw SomeError() }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.failure(SomeError()))) {
      $0.isNumberFactRequestInFlight = false
    }
  }

  func testIsEquatable() {

    XCTAssertTrue(isEquatable(1))
    XCTAssertTrue(isEquatable("Hello"))
    XCTAssertTrue(isEquatable(true))

    XCTAssertFalse(isEquatable({ $0 + 1 }))
    XCTAssertFalse(isEquatable(()))
    XCTAssertFalse(isEquatable((1, 2)))
    XCTAssertFalse(isEquatable(VStack {}))

    XCTAssertTrue(equals(1, 1))
    XCTAssertTrue(equals("Hello", "Hello"))
    XCTAssertFalse(equals(true, false))

//    XCTAssertFalse(equals((), ()))

  }
}
import SwiftUI

extension EffectsBasicsEnvironment {
  static let unimplemented = Self(
    fact: .unimplemented,
    mainQueue: .unimplemented
  )
}
