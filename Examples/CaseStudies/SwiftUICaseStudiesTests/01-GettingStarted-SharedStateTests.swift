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
      $0.profile = SharedState.Profile.State(currentTab: .profile, counter: CounterData())
    }
    await store.send(.profile(.resetCounterButtonTapped)) {
      $0.currentTab = .counter
      $0.profile = SharedState.Profile.State(currentTab: .counter, counter: CounterData())
    }
  }

  func testTabSelection() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.selectTab(.profile)) {
      $0.currentTab = .profile
      $0.profile = SharedState.Profile.State(currentTab: .profile, counter: CounterData())
    }
    await store.send(.selectTab(.counter)) {
      $0.currentTab = .counter
      $0.profile = SharedState.Profile.State(currentTab: .counter, counter: CounterData())
    }
  }

  func testSharedCounts() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.counter(.incrementButtonTapped)) {
      $0.counter.data.count = 1
      $0.counter.data.maxCount = 1
      $0.counter.data.numberOfCounts = 1
    }
    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.data.count = 0
      $0.counter.data.numberOfCounts = 2
    }
    await store.send(.counter(.decrementButtonTapped)) {
      $0.counter.data.count = -1
      $0.counter.data.minCount = -1
      $0.counter.data.numberOfCounts = 3
    }
  }

  func testIsPrimeWhenPrime() async {
    let store = TestStore(
      initialState: SharedState.Counter.State(
        alert: nil, data: CounterData(count: 3, maxCount: 0, minCount: 0, numberOfCounts: 0)
      )
    ) {
      SharedState.Counter()
    }

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
        alert: nil, data: CounterData(count: 6, maxCount: 0, minCount: 0, numberOfCounts: 0)
      )
    ) {
      SharedState.Counter()
    }

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
