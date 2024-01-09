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
    @Shares var stats: Stats

    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    }

    // let (oldState, newState) = SharedLocal.$cow.withValue(true) {
    //   // return (oldState, newState)
    // }
    // run reducer
    // 

    await store.send(.counter(.incrementButtonTapped))
    XCTAssertEqual(stats, Stats(count: 1, maxCount: 1, numberOfCounts: 1))

    await store.send(.counter(.decrementButtonTapped))
    XCTAssertEqual(stats, Stats(count: 0, maxCount: 1, numberOfCounts: 2))

    await store.send(.profile(.resetStatsButtonTapped))
    XCTAssertEqual(stats, Stats())
  }
}
