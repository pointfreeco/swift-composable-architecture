import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class EffectsCancellationTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testTrivia_SuccessfulRequest() throws {
    let store = TestStore(
      initialState: .init(),
      reducer: effectsCancellationReducer,
      environment: .init(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        trivia: { n in Effect(value: "\(n) is a good number Brent") }
      )
    )

    store.assert(
      .send(.stepperChanged(1)) {
        $0.count = 1
      },
      .send(.stepperChanged(0)) {
        $0.count = 0
      },
      .send(.triviaButtonTapped) {
        $0.isTriviaRequestInFlight = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.triviaResponse(.success("0 is a good number Brent"))) {
        $0.currentTrivia = "0 is a good number Brent"
        $0.isTriviaRequestInFlight = false
      }
    )
  }

  func testTrivia_FailedRequest() throws {
    let store = TestStore(
      initialState: .init(),
      reducer: effectsCancellationReducer,
      environment: .init(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        trivia: { _ in Fail(error: TriviaApiError()).eraseToEffect() }
      )
    )

    store.assert(
      .send(.triviaButtonTapped) {
        $0.isTriviaRequestInFlight = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.triviaResponse(.failure(TriviaApiError()))) {
        $0.isTriviaRequestInFlight = false
      }
    )
  }

  // NB: This tests that the cancel button really does cancel the in-flight API request.
  //
  // To see the real power of this test, try replacing the `.cancel` effect with a `.none` effect
  // in the `.cancelButtonTapped` action of the `effectsCancellationReducer`. This will cause the
  // test to fail, showing that we are exhaustively asserting that the effect truly is canceled and
  // will never emit.
  func testTrivia_CancelButtonCancelsRequest() throws {
    let store = TestStore(
      initialState: .init(),
      reducer: effectsCancellationReducer,
      environment: .init(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        trivia: { n in Effect(value: "\(n) is a good number Brent") }
      )
    )

    store.assert(
      .send(.triviaButtonTapped) {
        $0.isTriviaRequestInFlight = true
      },
      .send(.cancelButtonTapped) {
        $0.isTriviaRequestInFlight = false
      },
      .do {
        self.scheduler.run()
      }
    )
  }

  func testTrivia_PlusMinusButtonsCancelsRequest() throws {
    let store = TestStore(
      initialState: .init(),
      reducer: effectsCancellationReducer,
      environment: .init(
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        trivia: { n in Effect(value: "\(n) is a good number Brent") }
      )
    )

    store.assert(
      .send(.triviaButtonTapped) {
        $0.isTriviaRequestInFlight = true
      },
      .send(.stepperChanged(1)) {
        $0.count = 1
        $0.isTriviaRequestInFlight = false
      },
      .do {
        self.scheduler.advance()
      }
    )
  }
}
