import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class SharedStateTests: XCTestCase {
  func testTabRestoredOnReset() {
    let store = TestStore(
      initialState: SharedState(),
      reducer: sharedStateReducer,
      environment: ()
    )
    
    store.assert(
      .send(.selectTab(.profile)) {
        $0.currentTab = .profile
      },
      .send(.profile(.resetCounterButtonTapped)) {
        $0.currentTab = .counter
      })
  }

  func testTabSelection() {
    let store = TestStore(
      initialState: SharedState(),
      reducer: sharedStateReducer,
      environment: ()
    )

    store.assert(
      .send(.selectTab(.profile)) {
        $0.currentTab = .profile
      },
      .send(.selectTab(.counter)) {
        $0.currentTab = .counter
      })
  }

  func testIsPrimeWhenPrime() {
    let store = TestStore(
      initialState: SharedState.CounterState(alert: nil, count: 3, maxCount: 0, minCount: 0, numberOfCounts: 0),
      reducer: sharedStateCounterReducer,
      environment: ()
    )

    store.assert(
      .send(.isPrimeButtonTapped) {
        $0.alert = .init(
          title: "👍 The number \($0.count) is prime!"
        )
      },
      .send(.alertDismissed) {
        $0.alert = nil
      }
    )
  }

  func testIsPrimeWhenNotPrime() {
    let store = TestStore(
      initialState: SharedState.CounterState(alert: nil, count: 6, maxCount: 0, minCount: 0, numberOfCounts: 0),
      reducer: sharedStateCounterReducer,
      environment: ()
    )

    store.assert(
      .send(.isPrimeButtonTapped) {
        $0.alert = .init(
          title: "👎 The number \($0.count) is not prime :("
        )
      },
      .send(.alertDismissed) {
        $0.alert = nil
      }
    )
  }
}
