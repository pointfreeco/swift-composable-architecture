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
    @SharedDependency var stats: Stats

    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    await store.send(.counter(.incrementButtonTapped)) { _ in
      stats.increment()
    }

    await store.send(.counter(.decrementButtonTapped)) { _ in
      stats.decrement()
    }

    await store.send(.profile(.resetStatsButtonTapped)) { _ in
      stats = Stats()
    }
  }
}
