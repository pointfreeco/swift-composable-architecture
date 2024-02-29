import ComposableArchitecture
import XCTest

@testable import UIKitCaseStudies

@MainActor
final class UIKitCaseStudiesTests: XCTestCase {
  func testCountDown() async {
    let store = TestStore(initialState: Counter.State()) {
      Counter()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    await store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testCountDownList() async {
    let firstState = Counter.State()
    let secondState = Counter.State()
    let thirdState = Counter.State()

    let store = TestStore(
      initialState: CounterList.State(
        counters: [firstState, secondState, thirdState]
      )
    ) {
      CounterList()
    }

    await store.send(\.counters[id:firstState.id].incrementButtonTapped) {
      $0.counters[id: firstState.id]?.count = 1
    }
    await store.send(\.counters[id:firstState.id].decrementButtonTapped) {
      $0.counters[id: firstState.id]?.count = 0
    }

    await store.send(\.counters[id:secondState.id].incrementButtonTapped) {
      $0.counters[id: secondState.id]?.count = 1
    }
    await store.send(\.counters[id:secondState.id].decrementButtonTapped) {
      $0.counters[id: secondState.id]?.count = 0
    }

    await store.send(\.counters[id:thirdState.id].incrementButtonTapped) {
      $0.counters[id: thirdState.id]?.count = 1
    }
    await store.send(\.counters[id:thirdState.id].decrementButtonTapped) {
      $0.counters[id: thirdState.id]?.count = 0
    }
  }
}
