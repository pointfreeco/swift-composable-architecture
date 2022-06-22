import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class EffectsCancellationTests: XCTestCase {
  func testTrivia_SuccessfulRequest() async {
    let store = TestStore(
      initialState: EffectsCancellation.State(),
      reducer: EffectsCancellation()
        .dependency(\.factClient.fetch) { "\($0) is a good number Brent" }
        .dependency(\.mainQueue, .immediate)
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
    await store.receive(.triviaResponse(.success("0 is a good number Brent"))) {
      $0.currentTrivia = "0 is a good number Brent"
      $0.isTriviaRequestInFlight = false
    }
  }

  func testTrivia_FailedRequest() async {
    struct FactError: Error {}
    let store = TestStore(
      initialState: EffectsCancellation.State(),
      reducer: EffectsCancellation()
        .dependency(\.factClient.fetch) { _ in throw FactError() }
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    await store.receive(.triviaResponse(.failure(FactError()))) {
      $0.isTriviaRequestInFlight = false
    }
  }

  // NB: This tests that the cancel button really does cancel the in-flight API request.
  //
  // To see the real power of this test, try replacing the `.cancel` effect with a `.none` effect
  // in the `.cancelButtonTapped` action of `EffectsCancellation`. This will cause the test to fail,
  // showing that we are exhaustively asserting that the effect truly is canceled and will never
  // emit.
  func testTrivia_CancelButtonCancelsRequest() {
    let mainQueue = DispatchQueue.test
    let store = TestStore(
      initialState: EffectsCancellation.State(),
      reducer: EffectsCancellation()
        .dependency(\.factClient.fetch) { "\($0) is a good number Brent" }
        .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler())
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.send(.cancelButtonTapped) {
      $0.isTriviaRequestInFlight = false
    }
    mainQueue.run()
  }

  func testTrivia_PlusMinusButtonsCancelsRequest() {
    let mainQueue = DispatchQueue.test
    let store = TestStore(
      initialState: EffectsCancellation.State(),
      reducer: EffectsCancellation()
        .dependency(\.factClient.fetch) { "\($0) is a good number Brent" }
        .dependency(\.mainQueue, mainQueue.eraseToAnyScheduler())
    )

    store.send(.triviaButtonTapped) {
      $0.isTriviaRequestInFlight = true
    }
    store.send(.stepperChanged(1)) {
      $0.count = 1
      $0.isTriviaRequestInFlight = false
    }
    mainQueue.advance()
  }
}
