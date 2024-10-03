import ComposableArchitecture
import Testing

@testable import SwiftUICaseStudies

@MainActor
struct SharedStateUserDefaultsTests {
  @Test
  func tabSelection() async {
    let store = TestStore(initialState: SharedStateUserDefaults.State()) {
      SharedStateUserDefaults()
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
    let store = TestStore(initialState: SharedStateUserDefaults.State()) {
      SharedStateUserDefaults()
    }

    await store.send(.counter(.incrementButtonTapped)) {
      $0.counter.count = 1
    }

    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.count = 0
    }

    await store.send(.profile(.resetStatsButtonTapped)) {
      $0.profile.count = 0
    }
  }

  @Test
  func alert() async {
    let store = TestStore(initialState: SharedStateUserDefaults.State()) {
      SharedStateUserDefaults()
    }

    await store.send(.counter(.isPrimeButtonTapped)) {
      $0.counter.alert = AlertState {
        TextState("👎 The number 0 is not prime :(")
      }
    }
  }
}
