import ComposableArchitecture
import Testing

@testable import SwiftUICaseStudies

@MainActor
struct RefreshableTests {
  @Test
  func happyPath() async {
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
    await store.receive(\.factResponse.success) {
      $0.fact = "1 is a good number."
    }
  }

  @Test
  func unhappyPath() async {
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
    await store.receive(\.factResponse.failure)
  }

  @Test
  func cancellation() async {
    let store = TestStore(initialState: Refreshable.State()) {
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
