import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class RefreshableTests: XCTestCase {
  func testHappyPath() async {
    let store = TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = { "\($0) is a good number." }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(.factResponse(.success("1 is a good number."))) {
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() async {
    struct FactError: Equatable, Error {}

    let store = TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = { _ in throw FactError() }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(.factResponse(.failure(FactError())))
  }

  func testCancellation() async {
    let store = TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return "\($0) is a good number."
      }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.send(.cancelButtonTapped)
  }
}
