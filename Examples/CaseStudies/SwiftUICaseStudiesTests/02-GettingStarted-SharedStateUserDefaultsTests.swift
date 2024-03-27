import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class SharedStateUserDefaultsTests: XCTestCase {
  @MainActor
  func testTabSelection() async {
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

  @MainActor
  func testSharedCounts() async {
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

  @MainActor
  func testAlert() async {
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
