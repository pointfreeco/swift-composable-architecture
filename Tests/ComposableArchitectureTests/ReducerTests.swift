import Combine
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
    XCTAssertEqual(state, 1)
  }

  #if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testCombine_EffectsAreMerged() async throws {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        enum Action: Equatable {
          case increment
        }

        struct Delayed: ReducerProtocol {
          typealias State = Int

          @Dependency(\.continuousClock) var clock

          let delay: Duration
          let setValue: @Sendable () async -> Void

          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            state += 1
            return .fireAndForget {
              try await self.clock.sleep(for: self.delay)
              await self.setValue()
            }
          }
        }

        var fastValue: Int? = nil
        var slowValue: Int? = nil

        let store = TestStore(
          initialState: 0,
          reducer: CombineReducers {
            Delayed(delay: .seconds(1), setValue: { @MainActor in fastValue = 42 })
            Delayed(delay: .seconds(2), setValue: { @MainActor in slowValue = 1729 })
          }
        )

        let clock = TestClock()
        store.dependencies.continuousClock = clock

        await store.send(.increment) {
          $0 = 2
        }
        // Waiting a second causes the fast effect to fire.
        await clock.advance(by: .seconds(1))
        try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
        XCTAssertEqual(fastValue, 42)
        XCTAssertEqual(slowValue, nil)
        // Waiting one more second causes the slow effect to fire. This proves that the effects
        // are merged together, as opposed to concatenated.
        await clock.advance(by: .seconds(1))
        await store.finish()
        XCTAssertEqual(fastValue, 42)
        XCTAssertEqual(slowValue, 1729)
      }
    }
  #endif

  func testCombine() async {
    enum Action: Equatable {
      case increment
    }

    struct One: ReducerProtocol {
      typealias State = Int
      let effect: @Sendable () async -> Void
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        state += 1
        return .fireAndForget {
          await self.effect()
        }
      }
    }

    var first = false
    var second = false

    let store = TestStore(
      initialState: 0,
      reducer: CombineReducers {
        One(effect: { @MainActor in first = true })
        One(effect: { @MainActor in second = true })
      }
    )

    await store
      .send(.increment) { $0 = 2 }
      .finish()

    XCTAssertTrue(first)
    XCTAssertTrue(second)
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

      XCTAssertEqual(
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

      XCTAssertEqual(
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
