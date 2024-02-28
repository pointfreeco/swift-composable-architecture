import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class SharedStateTests: XCTestCase {
  func testTabSelection() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
    }
    await store.send(.selectTab(.counter)) {
      $0.currentTab = .counter
    }
  }

  func testSharedCounts() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(\.counter.incrementButtonTapped) {
      $0.counter.stats.increment()
      $0.profile.stats.increment()
    }
    await store.send(\.counter.decrementButtonTapped) {
      $0.counter.stats.decrement()
      $0.profile.stats.decrement()
    }
    await store.send(\.profile.resetStatsButtonTapped) {
      $0.counter.stats = Stats()
      $0.profile.stats = Stats()
    }
  }

  func testAlert() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(\.counter.isPrimeButtonTapped) {
      $0.counter.alert = AlertState {
        TextState("👎 The number 0 is not prime :(")
      }
    }
  }
}
