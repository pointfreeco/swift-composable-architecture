import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class EffectsCancellationTests: XCTestCase {
  @MainActor
  func testTrivia_SuccessfulRequest() async {
    let store = TestStore(initialState: EffectsCancellation.State()) {
      EffectsCancellation()
    } withDependencies: {
      $0.factClient.fetch = { "\($0) is a good number Brent" }
    }

    await store.send(.stepperChanged(1)) {
      $0.count = 1
    }
    await store.send(.stepperChanged(0)) {
      $0.count = 0
    }
    await store.send(.factButtonTapped) {
      $0.isFactRequestInFlight = true
    }
    await store.receive(\.factResponse.success) {
      $0.currentFact = "0 is a good number Brent"
      $0.isFactRequestInFlight = false
    }
  }

  @MainActor
  func testTrivia_FailedRequest() async {
    struct FactError: Equatable, Error {}
    let store = TestStore(initialState: EffectsCancellation.State()) {
      EffectsCancellation()
    } withDependencies: {
      $0.factClient.fetch = { _ in throw FactError() }
    }

    await store.send(.factButtonTapped) {
      $0.isFactRequestInFlight = true
    }
    await store.receive(\.factResponse.failure) {
      $0.isFactRequestInFlight = false
    }
  }

  // NB: This tests that the cancel button really does cancel the in-flight API request.
  //
  // To see the real power of this test, try replacing the `.cancel` effect with a `.none` effect
  // in the `.cancelButtonTapped` action of the `effectsCancellationReducer`. This will cause the
  // test to fail, showing that we are exhaustively asserting that the effect truly is canceled and
  // will never emit.
  @MainActor
  func testTrivia_CancelButtonCancelsRequest() async {
    let store = TestStore(initialState: EffectsCancellation.State()) {
      EffectsCancellation()
    } withDependencies: {
      $0.factClient.fetch = { _ in try await Task.never() }
    }

    await store.send(.factButtonTapped) {
      $0.isFactRequestInFlight = true
    }
    await store.send(.cancelButtonTapped) {
      $0.isFactRequestInFlight = false
    }
  }

  @MainActor
  func testTrivia_PlusMinusButtonsCancelsRequest() async {
    let store = TestStore(initialState: EffectsCancellation.State()) {
      EffectsCancellation()
    } withDependencies: {
      $0.factClient.fetch = { _ in try await Task.never() }
    }

    await store.send(.factButtonTapped) {
      $0.isFactRequestInFlight = true
    }
    await store.send(.stepperChanged(1)) {
      $0.count = 1
      $0.isFactRequestInFlight = false
    }
  }
}
