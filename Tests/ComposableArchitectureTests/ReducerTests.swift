import Combine
import CombineSchedulers
import ComposableArchitecture
import CustomDump
import XCTest
import os.signpost

final class ReducerTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCallableAsFunction() {
    let reducer = Reducer<Int, Void, Void> { state, _, _ in
      state += 1
      return .none
    }

    var state = 0
    _ = reducer.run(&state, (), ())
    XCTAssertNoDifference(state, 1)
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

    let mainQueue = DispatchQueue.test
    let store = TestStore(
      initialState: 0,
      reducer: .combine(fastReducer, slowReducer),
      environment: mainQueue.eraseToAnyScheduler()
    )

    store.send(.increment) {
      $0 = 2
    }
    // Waiting a second causes the fast effect to fire.
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(fastValue, 42)
    // Waiting one more second causes the slow effect to fire. This proves that the effects
    // are merged together, as opposed to concatenated.
    mainQueue.advance(by: 1)
    XCTAssertNoDifference(slowValue, 1729)
  }

  func testCombine() {
    enum Action: Equatable {
      case increment
    }

    var childEffectExecuted = false
    let childReducer = Reducer<Int, Action, Void> { state, _, _ in
      state += 1
      return Effect.fireAndForget { childEffectExecuted = true }
        .eraseToEffect()
    }

    var mainEffectExecuted = false
    let mainReducer = Reducer<Int, Action, Void> { state, _, _ in
      state += 1
      return Effect.fireAndForget { mainEffectExecuted = true }
        .eraseToEffect()
    }
    .combined(with: childReducer)

    let store = TestStore(
      initialState: 0,
      reducer: mainReducer,
      environment: ()
    )

    store.send(.increment) {
      $0 = 2
    }

    XCTAssertTrue(childEffectExecuted)
    XCTAssertTrue(mainEffectExecuted)
  }

  func testDebug() {
    var logs: [String] = []
    let logsExpectation = self.expectation(description: "logs")
    logsExpectation.expectedFulfillmentCount = 2

    let reducer = Reducer<DebugState, DebugAction, Void> { state, action, _ in
      switch action {
      case .incrWithBool:
        return .none
      case .incr:
        state.count += 1
        return .none
      case .noop:
        return .none
      }
    }
    .debug("[prefix]") { _ in
      DebugEnvironment(
        printer: {
          logs.append($0)
          logsExpectation.fulfill()
        }
      )
    }

    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: ()
    )
    store.send(.incr) { $0.count = 1 }
    store.send(.noop)

    self.wait(for: [logsExpectation], timeout: 2)

    XCTAssertNoDifference(
      logs,
      [
        #"""
        [prefix]: received action:
          DebugAction.incr
        - DebugState(count: 0)
        + DebugState(count: 1)

        """#,
        #"""
        [prefix]: received action:
          DebugAction.noop
          (No state changes)

        """#,
      ]
    )
  }

  func testDebug_ActionFormat_OnlyLabels() {
    var logs: [String] = []
    let logsExpectation = self.expectation(description: "logs")

    let reducer = Reducer<DebugState, DebugAction, Void> { state, action, _ in
      switch action {
      case let .incrWithBool(bool):
        state.count += bool ? 1 : 0
        return .none
      default:
        return .none
      }
    }
    .debug("[prefix]", actionFormat: .labelsOnly) { _ in
      DebugEnvironment(
        printer: {
          logs.append($0)
          logsExpectation.fulfill()
        }
      )
    }

    let viewStore = ViewStore(
      Store(
        initialState: .init(),
        reducer: reducer,
        environment: ()
      )
    )
    viewStore.send(.incrWithBool(true))

    self.wait(for: [logsExpectation], timeout: 2)

    XCTAssertNoDifference(
      logs,
      [
        #"""
        [prefix]: received action:
          DebugAction.incrWithBool
        - DebugState(count: 0)
        + DebugState(count: 1)

        """#
      ]
    )
  }

  func testDefaultSignpost() {
    let reducer = Reducer<Int, Void, Void>.empty.signpost(log: .default)
    var n = 0
    let effect = reducer.run(&n, (), ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }

  func testDisabledSignpost() {
    let reducer = Reducer<Int, Void, Void>.empty.signpost(log: .disabled)
    var n = 0
    let effect = reducer.run(&n, (), ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }
}

enum DebugAction: Equatable {
  case incrWithBool(Bool)
  case incr, noop
}
struct DebugState: Equatable { var count = 0 }
