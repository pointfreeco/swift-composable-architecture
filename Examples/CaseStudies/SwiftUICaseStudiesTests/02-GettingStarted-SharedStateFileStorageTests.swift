import ComposableArchitecture
import Testing

@testable import SwiftUICaseStudies

@MainActor
struct SharedStateFileStorageTests {
  @Test
  func tabSelection() async {
    let store = TestStore(initialState: SharedStateFileStorage.State()) {
      SharedStateFileStorage()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
    }
    await store.send(.selectTab(.counter)) {
      $0.currentTab = .counter
    }
  }

  @Test
  func sharedCounts() async {
    let store = TestStore(initialState: SharedStateFileStorage.State()) {
      SharedStateFileStorage()
    }

    await store.send(\.counter.incrementButtonTapped) {
      $0.counter.$stats.withLock { $0.increment() }
    }

    await store.send(\.counter.decrementButtonTapped) {
      $0.counter.$stats.withLock { $0.decrement() }
    }

    await store.send(\.profile.resetStatsButtonTapped) {
      $0.profile.$stats.withLock { $0 = Stats() }
    }
  }

  @Test
  func alert() async {
    let store = TestStore(initialState: SharedStateFileStorage.State()) {
      SharedStateFileStorage()
    }

    await store.send(\.counter.isPrimeButtonTapped) {
      $0.counter.alert = AlertState {
        TextState("👎 The number 0 is not prime :(")
      }
    }
  }
}
