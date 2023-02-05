import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class SharedStateTests: XCTestCase {
  func testTabRestoredOnReset() async {
    let store = TestStore(
      initialState: SharedState.State(),
      reducer: SharedState()
    )

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
      $0.profile = SharedState.Profile.State(
        currentTab: .profile, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
    await store.send(.profile(.resetCounterButtonTapped)) {
      $0.currentTab = .counter
      $0.profile = SharedState.Profile.State(
        currentTab: .counter, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
  }

  func testTabSelection() async {
    let store = TestStore(
      initialState: SharedState.State(),
      reducer: SharedState()
    )

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
      $0.profile = SharedState.Profile.State(
        currentTab: .profile, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
    await store.send(.selectTab(.counter)) {
      $0.currentTab = .counter
      $0.profile = SharedState.Profile.State(
        currentTab: .counter, count: 0, maxCount: 0, minCount: 0, numberOfCounts: 0
      )
    }
  }

  func testSharedCounts() async {
    let store = TestStore(
      initialState: SharedState.State(),
      reducer: SharedState()
    )

    await store.send(.counter(.incrementButtonTapped)) {
      $0.counter.count = 1
      $0.counter.maxCount = 1
      $0.counter.numberOfCounts = 1
    }
    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.count = 0
      $0.counter.numberOfCounts = 2
    }
    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.count = -1
      $0.counter.minCount = -1
      $0.counter.numberOfCounts = 3
    }
  }

  func testIsPrimeWhenPrime() async {
    let store = TestStore(
      initialState: SharedState.Counter.State(
        alert: nil, count: 3, maxCount: 0, minCount: 0, numberOfCounts: 0
      ),
      reducer: SharedState.Counter()
    )

    await store.send(.isPrimeButtonTapped) {
      $0.alert = AlertState {
        TextState("👍 The number 3 is prime!")
      }
    }
    await store.send(.alertDismissed) {
      $0.alert = nil
    }
  }

  func testIsPrimeWhenNotPrime() async {
    let store = TestStore(
      initialState: SharedState.Counter.State(
        alert: nil, count: 6, maxCount: 0, minCount: 0, numberOfCounts: 0
      ),
      reducer: SharedState.Counter()
    )

    await store.send(.isPrimeButtonTapped) {
      $0.alert = AlertState {
        TextState("👎 The number 6 is not prime :(")
      }
    }
    await store.send(.alertDismissed) {
      $0.alert = nil
    }
  }
}
