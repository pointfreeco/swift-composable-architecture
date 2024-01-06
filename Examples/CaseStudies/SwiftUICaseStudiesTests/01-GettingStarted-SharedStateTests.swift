import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class SharedStateTests: XCTestCase {
  func testTabRestoredOnReset() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
      $0.profile = Profile.State(
        currentTab: .profile, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
    await store.send(.profile(.resetStatsButtonTapped)) {
      $0.currentTab = .stats
      $0.profile = Profile.State(
        currentTab: .stats, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
  }

  func testTabSelection() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
      $0.profile = Profile.State(
        currentTab: .profile, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
    await store.send(.selectTab(.stats)) {
      $0.currentTab = .stats
      $0.profile = Profile.State(
        currentTab: .stats, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
  }

  func testSharedCounts() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.stats(.incrementButtonTapped)) {
      $0.stats.count = 1
      $0.stats.maxCount = 1
      $0.stats.numberOfCounts = 1
    }
    await store.send(.stats(.decrementButtonTapped)) {
      $0.stats.count = 0
      $0.stats.numberOfCounts = 2
    }
    await store.send(.stats(.decrementButtonTapped)) {
      $0.stats.count = -1
      $0.stats.minCount = -1
      $0.stats.numberOfCounts = 3
    }
  }

  func testIsPrimeWhenPrime() async {
    let store = TestStore(
      initialState: Stats.State(
        alert: nil, count: 3, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    ) {
      Stats()
    }

    await store.send(.isPrimeButtonTapped) {
      $0.alert = AlertState {
        TextState("👍 The number 3 is prime!")
      }
    }
    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }

  func testIsPrimeWhenNotPrime() async {
    let store = TestStore(
      initialState: Stats.State(
        alert: nil, count: 6, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    ) {
      Stats()
    }

    await store.send(.isPrimeButtonTapped) {
      $0.alert = AlertState {
        TextState("👎 The number 6 is not prime :(")
      }
    }
    await store.send(.alert(.dismiss)) {
      $0.alert = nil
    }
  }
}
