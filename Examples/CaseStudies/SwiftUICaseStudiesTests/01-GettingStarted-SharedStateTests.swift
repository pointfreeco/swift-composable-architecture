import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class SharedStateTests: XCTestCase {
  func testSharedCounts() async {
    let store = TestStore(initialState: SharedState.State()) {
      SharedState()
    } withDependencies: {
      // TODO: how to clean this up
      //$0[Shared<SharedState.Counter.State>.self] = Shared(SharedState.Counter.State())
      _ = $0
    }

    await XCTAssertDifference(store.state.counter.value) {
      _ = await store.send(.counter(.incrementButtonTapped))
    } changes: {
      $0.count = 1
      $0.maxCount = 1
      $0.numberOfCounts = 1
    }
    await XCTAssertDifference(store.state.counter.value) {
      _ = await store.send(.counter(.decrementButtonTapped))
    } changes: {
      $0.count = 0
      $0.numberOfCounts = 2
    }
  }
//
//  func testIsPrimeWhenPrime() async {
//    let store = TestStore(
//      initialState: SharedState.Counter.State(
//        alert: nil, count: 3, maxCount: 0, minCount: 0, numberOfCounts: 0
//      )
//    ) {
//      SharedState.Counter()
//    }
//
//    await store.send(.isPrimeButtonTapped) {
//      $0.alert = AlertState {
//        TextState("👍 The number 3 is prime!")
//      }
//    }
//    await store.send(.alert(.dismiss)) {
//      $0.alert = nil
//    }
//  }
//
//  func testIsPrimeWhenNotPrime() async {
//    let store = TestStore(
//      initialState: SharedState.Counter.State(
//        alert: nil, count: 6, maxCount: 0, minCount: 0, numberOfCounts: 0
//      )
//    ) {
//      SharedState.Counter()
//    }
//
//    await store.send(.isPrimeButtonTapped) {
//      $0.alert = AlertState {
//        TextState("👎 The number 6 is not prime :(")
//      }
//    }
//    await store.send(.alert(.dismiss)) {
//      $0.alert = nil
//    }
//  }
}
