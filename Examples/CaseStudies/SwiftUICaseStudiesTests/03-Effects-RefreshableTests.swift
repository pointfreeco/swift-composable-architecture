import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class RefreshableTests: XCTestCase {
  func testHappyPath() async {
    let store = await TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = { "\($0) is a good number." }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(\.factResponse.success) {
      $0.fact = "1 is a good number."
    }
  }

  func testUnhappyPath() async {
    struct FactError: Equatable, Error {}

    let store = await TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = { _ in throw FactError() }
      $0.continuousClock = ImmediateClock()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.refresh)
    await store.receive(\.factResponse.failure)
  }

  func testCancellation() async {
    let store = await TestStore(initialState: Refreshable.State()) {
      Refreshable()
    } withDependencies: {
      $0.factClient.fetch = {
        try await Task.sleep(for: .seconds(1))
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
