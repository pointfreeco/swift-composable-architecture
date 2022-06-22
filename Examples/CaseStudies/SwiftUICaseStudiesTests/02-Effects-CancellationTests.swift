import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class EffectsCancellationTests: XCTestCase {
  func testTrivia_SuccessfulRequest() {
    let store = TestStore(
      initialState: EffectsCancellationState(),
      reducer: effectsCancellationReducer,
      environment: EffectsCancellationEnvironment(
        fact: FactClient(fetch: { n in Effect(value: "\(n) is a good number Brent") }),
        mainQueue: .immediate
      )
    )

    store.send(.stepperChanged(1)) {
      $0.count = 1
    }
    store.send(.stepperChanged(0)) {
      $0.count = 0
    }
    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.receive(.triviaResponse(.success("0 is a good number Brent"))) {
      $0.currentTrivia = "0 is a good number Brent"
      $0.isTriviaRequestInFlight = false
    }
  }

  func testTrivia_FailedRequest() {
    let store = TestStore(
      initialState: EffectsCancellationState(),
      reducer: effectsCancellationReducer,
      environment: EffectsCancellationEnvironment(
        fact: FactClient(fetch: { _ in Fail(error: FactClient.Error()).eraseToEffect() }),
        mainQueue: .immediate
      )
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.receive(.triviaResponse(.failure(FactClient.Error()))) {
      $0.isTriviaRequestInFlight = false
    }
  }

  // NB: This tests that the cancel button really does cancel the in-flight API request.
  //
  // To see the real power of this test, try replacing the `.cancel` effect with a `.none` effect
  // in the `.cancelButtonTapped` action of the `effectsCancellationReducer`. This will cause the
  // test to fail, showing that we are exhaustively asserting that the effect truly is canceled and
  // will never emit.
  func testTrivia_CancelButtonCancelsRequest() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: EffectsCancellationState(),
      reducer: effectsCancellationReducer,
      environment: EffectsCancellationEnvironment(
        fact: FactClient(fetch: { n in Effect(value: "\(n) is a good number Brent") }),
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.send(.cancelButtonTapped) {
      $0.isTriviaRequestInFlight = false
    }
    scheduler.run()
  }

  func testTrivia_PlusMinusButtonsCancelsRequest() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: EffectsCancellationState(),
      reducer: effectsCancellationReducer,
      environment: EffectsCancellationEnvironment(
        fact: FactClient(fetch: { n in Effect(value: "\(n) is a good number Brent") }),
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.send(.stepperChanged(1)) {
      $0.count = 1
      $0.isTriviaRequestInFlight = false
    }
    scheduler.advance()
  }
}
