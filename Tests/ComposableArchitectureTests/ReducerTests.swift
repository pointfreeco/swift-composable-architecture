import Combine
import CombineSchedulers
import ComposableArchitecture
import CustomDump
import XCTest
import os.signpost

@MainActor
final class ReducerTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCallableAsFunction() {
    let reducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    var state = 0
    _ = reducer.reduce(into: &state, action: ())
    XCTAssertNoDifference(state, 1)
  }

  func testCombine_EffectsAreMerged() async {
    typealias Scheduler = AnySchedulerOf<DispatchQueue>
    enum Action: Equatable {
      case increment
    }

    struct Delayed: ReducerProtocol {
      typealias State = Int

      @Dependency(\.mainQueue) var mainQueue

      let delay: DispatchQueue.SchedulerTimeType.Stride
      let setValue: @Sendable () async -> Void

      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        state += 1
        return .fireAndForget {
          try await self.mainQueue.sleep(for: self.delay)
          await self.setValue()
        }
      }
    }

    let fastValue = ActorIsolated<Int?>(nil)
    let slowValue = ActorIsolated<Int?>(nil)

    let store = TestStore(
      initialState: 0,
      reducer: CombineReducers {
        Delayed(delay: 1, setValue: { await fastValue.setValue(42) })
        Delayed(delay: 2, setValue: { await slowValue.setValue(1729) })
      }
    )

    let mainQueue = DispatchQueue.test
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

    await store.send(.increment) {
      $0 = 2
    }
    // Waiting a second causes the fast effect to fire.
    await mainQueue.advance(by: 1)
    await fastValue.withValue { XCTAssertEqual($0, 42) }
    // Waiting one more second causes the slow effect to fire. This proves that the effects
    // are merged together, as opposed to concatenated.
    await mainQueue.advance(by: 1)
    await slowValue.withValue { XCTAssertEqual($0, 1729) }
  }

  func testCombine() async {
    enum Action: Equatable {
      case increment
    }

    struct One: ReducerProtocol {
      typealias State = Int
      let effect: @Sendable () async -> Void
      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        state += 1
        return .fireAndForget {
          await self.effect()
        }
      }
    }

    let first = ActorIsolated(false)
    let second = ActorIsolated(false)

    let store = TestStore(
      initialState: 0,
      reducer: CombineReducers {
        One(effect: { await first.setValue(true) })
        One(effect: { await second.setValue(true) })
      }
    )

    await store
      .send(.increment) { $0 = 2 }
      .finish()

    await first.withValue { XCTAssertTrue($0) }
    await second.withValue { XCTAssertTrue($0) }
  }

  #if DEBUG
    func testDebug() async {
      enum DebugAction: Equatable {
        case incrWithBool(Bool)
        case incr, noop
      }
      struct DebugState: Equatable { var count = 0 }

      var logs: [String] = []
      let logsExpectation = self.expectation(description: "logs")
      logsExpectation.expectedFulfillmentCount = 2

      let reducer = AnyReducer<DebugState, DebugAction, Void> { state, action, _ in
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
      await store.send(.incr) { $0.count = 1 }
      await store.send(.noop)

      self.wait(for: [logsExpectation], timeout: 5)

      XCTAssertNoDifference(
        logs,
        [
          #"""
          [prefix]: received action:
            ReducerTests.DebugAction.incr
          - ReducerTests.DebugState(count: 0)
          + ReducerTests.DebugState(count: 1)

          """#,
          #"""
          [prefix]: received action:
            ReducerTests.DebugAction.noop
            (No state changes)

          """#,
        ]
      )
    }

    func testDebug_ActionFormat_OnlyLabels() {
      enum DebugAction: Equatable {
        case incrWithBool(Bool)
        case incr, noop
      }
      struct DebugState: Equatable { var count = 0 }

      var logs: [String] = []
      let logsExpectation = self.expectation(description: "logs")

      let reducer = AnyReducer<DebugState, DebugAction, Void> { state, action, _ in
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

      self.wait(for: [logsExpectation], timeout: 5)

      XCTAssertNoDifference(
        logs,
        [
          #"""
          [prefix]: received action:
            ReducerTests.DebugAction.incrWithBool
          - ReducerTests.DebugState(count: 0)
          + ReducerTests.DebugState(count: 1)

          """#
        ]
      )
    }
  #endif

  func testDefaultSignpost() {
    let reducer = EmptyReducer<Int, Void>().signpost(log: .default)
    var n = 0
    let effect = reducer.reduce(into: &n, action: ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }

  func testDisabledSignpost() {
    let reducer = EmptyReducer<Int, Void>().signpost(log: .disabled)
    var n = 0
    let effect = reducer.reduce(into: &n, action: ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }
}
