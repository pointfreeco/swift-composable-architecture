import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class SharedStateInMemoryTests: XCTestCase {
  @MainActor
  func testTabSelection() async {
    let store = TestStore(initialState: SharedStateInMemory.State()) {
      SharedStateInMemory()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
    }
    await store.send(.selectTab(.counter)) {
      $0.currentTab = .counter
    }
  }

  @MainActor
  func testSharedCounts() async {
    let store = TestStore(initialState: SharedStateInMemory.State()) {
      SharedStateInMemory()
    }

    await store.send(.counter(.incrementButtonTapped)) {
      $0.counter.stats.increment()
    }

    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.stats.decrement()
    }

    await store.send(.profile(.resetStatsButtonTapped)) {
      $0.profile.stats = Stats()
    }
  }

  @MainActor
  func testAlert() async {
    let store = TestStore(initialState: SharedStateInMemory.State()) {
      SharedStateInMemory()
    }

    await store.send(.counter(.isPrimeButtonTapped)) {
      $0.counter.alert = AlertState {
        TextState("👎 The number 0 is not prime :(")
      }
    }
  }
}
