import Combine
import ComposableArchitecture
import ComposableArchitectureTestSupport
import XCTest

final class ReducerTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCallableAsFunction() {
    let reducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    var state = 0
    _ = reducer.callAsFunction(&state, (), ())
    XCTAssertEqual(state, 1)
  }

  func testSimpleReducer() {
    let reducer = Reducer<Int, Void, Void> { state, _, _ in state += 1
      return .none
    }

    var state = 0
    _ = reducer.callAsFunction(&state, ())
    XCTAssertEqual(state, 1)
  }

  func testCombine_EffectsAreMerged() {
    typealias Scheduler = AnySchedulerOf<DispatchQueue>
    enum Action: Equatable {
      case increment
    }

    var fastValue: Int?
    let fastReducer = Reducer<Int, Action, Scheduler> { state, _, scheduler in
      state += 1
      return Effect.fireAndForget { fastValue = 42 }
        .delay(for: 1, scheduler: scheduler)
        .eraseToEffect()
    }

    var slowValue: Int?
    let slowReducer = Reducer<Int, Action, Scheduler> { state, _, scheduler in
      state += 1
      return Effect.fireAndForget { slowValue = 1729 }
        .delay(for: 2, scheduler: scheduler)
        .eraseToEffect()
    }

    let scheduler = DispatchQueue.testScheduler
    let store = TestStore(
      initialState: 0,
      reducer: .combine(fastReducer, slowReducer),
      environment: scheduler.eraseToAnyScheduler()
    )

    store.assert(
      .send(.increment) {
        $0 = 2
      },
      // Waiting a second causes the fast effect to fire.
      .do { scheduler.advance(by: 1) },
      .do { XCTAssertEqual(fastValue, 42) },
      // Waiting one more second causes the slow effect to fire. This proves that the effects
      // are merged together, as opposed to concatenated.
      .do { scheduler.advance(by: 1) },
      .do { XCTAssertEqual(slowValue, 1729) }
    )
  }

  func testPrint() {
    struct Unit: Equatable {}
    struct State: Equatable { var count = 0 }

    var logs: [String] = []

    let expectation = self.expectation(description: "printed")

    let reducer = Reducer<State, Unit, Void> { state, _, _ in
      state.count += 1
      return .none
    }
    .debug(prefix: "[prefix]") { _ in
      DebugEnvironment(
        printer: {
          logs.append($0)
          expectation.fulfill()
        }
      )
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: ()
    )
    store.assert(
      .send(Unit()) { $0.count = 1 }
    )

    self.wait(for: [expectation], timeout: 1)

    XCTAssertEqual(
      logs,
      [
        #"""
        [prefix]: received action:
          Unit()
          State(
        −   count: 0
        +   count: 1
          )

        """#
      ]
    )
  }
}
