#if DEBUG
  import ComposableArchitecture
  import XCTest

  @MainActor
  final class TestStoreFailureTests: XCTestCase {
    func testNoStateChangeFailure() {
      enum Action { case first, second }
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Action> { state, action in
          switch action {
          case .first: return .init(value: .second)
          case .second: return .none
          }
        }
      )

      XCTExpectFailure {
        _ = store.send(.first) { _ = $0 }
      } issueMatcher: {
        $0.compactDescription == """
          Expected state to change, but no change occurred.

          The trailing closure made no observable modifications to state. If no change to state is \
          expected, omit the trailing closure.
          """
      }

      XCTExpectFailure {
        store.receive(.second) { _ = $0 }
      } issueMatcher: {
        $0.compactDescription == """
          Expected state to change, but no change occurred.

          The trailing closure made no observable modifications to state. If no change to state is \
          expected, omit the trailing closure.
          """
      }
    }

    func testStateChangeFailure() {
      struct State: Equatable { var count = 0 }
      let store = TestStore(
        initialState: .init(),
        reducer: Reduce<State, Void> { state, action in state.count += 1
          return .none
        }
      )

      XCTExpectFailure {
        _ = store.send(()) { $0.count = 0 }
      } issueMatcher: {
        $0.compactDescription == """
          A state change does not match expectation: …

              − TestStoreFailureTests.State(count: 0)
              + TestStoreFailureTests.State(count: 1)

          (Expected: −, Actual: +)
          """
      }
    }

    func testUnexpectedStateChangeOnSendFailure() {
      struct State: Equatable { var count = 0 }
      let store = TestStore(
        initialState: .init(),
        reducer: Reduce<State, Void> { state, action in state.count += 1
          return .none
        }
      )

      _ = XCTExpectFailure {
        store.send(())
      } issueMatcher: {
        $0.compactDescription == """
          State was not expected to change, but a change occurred: …

              − TestStoreFailureTests.State(count: 0)
              + TestStoreFailureTests.State(count: 1)

          (Expected: −, Actual: +)
          """
      }
    }

    func testUnexpectedStateChangeOnReceiveFailure() {
      struct State: Equatable { var count = 0 }
      enum Action { case first, second }
      let store = TestStore(
        initialState: .init(),
        reducer: Reduce<State, Action> { state, action in
          switch action {
          case .first: return .init(value: .second)
          case .second:
            state.count += 1
            return .none
          }
        }
      )

      store.send(.first)
      XCTExpectFailure {
        store.receive(.second)
      } issueMatcher: {
        $0.compactDescription == """
          State was not expected to change, but a change occurred: …

              − TestStoreFailureTests.State(count: 0)
              + TestStoreFailureTests.State(count: 1)

          (Expected: −, Actual: +)
          """
      }
    }

    func testReceivedActionAfterDeinit() {
      XCTExpectFailure {
        do {
          enum Action { case first, second }
          let store = TestStore(
            initialState: 0,
            reducer: Reduce<Int, Action> { state, action in
              switch action {
              case .first: return .init(value: .second)
              case .second: return .none
              }
            }
          )
          store.send(.first)
        }
      } issueMatcher: {
        $0.compactDescription == """
          The store received 1 unexpected action after this one: …

          Unhandled actions: [
            [0]: TestStoreFailureTests.Action.second
          ]
          """
      }
    }

    func testEffectInFlightAfterDeinit() {
      XCTExpectFailure {
        do {
          let store = TestStore(
            initialState: 0,
            reducer: Reduce<Int, Void> { state, action in
              .task { try await Task.sleep(nanoseconds: NSEC_PER_SEC) }
            }
          )
          store.send(())
        }
      } issueMatcher: {
        $0.compactDescription == """
          An effect returned for this action is still running. It must complete before the end of \
          the test. …

          To fix, inspect any effects the reducer returns for this action and ensure that all of \
          them complete by the end of the test. There are a few reasons why an effect may not have \
          completed:

          • If using async/await in your effect, it may need a little bit of time to properly \
          finish. To fix you can simply perform "await store.finish()" at the end of your test.

          • If an effect uses a clock/scheduler (via "receive(on:)", "delay", "debounce", etc.), \
          make sure that you wait enough time for it to perform the effect. If you are using a \
          test clock/scheduler, advance it so that the effects may complete, or consider using an \
          immediate clock/scheduler to immediately perform the effect instead.

          • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
          then make sure those effects are torn down by marking the effect ".cancellable" and \
          returning a corresponding cancellation effect ("Effect.cancel") from another action, or, \
          if your effect is driven by a Combine subject, send it a completion.
          """
      }
    }

    func testSendActionBeforeReceivingFailure() {
      enum Action { case first, second }
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Action> { state, action in
          switch action {
          case .first: return .init(value: .second)
          case .second: return .none
          }
        }
      )

      XCTExpectFailure {
        store.send(.first)
        store.send(.first)
        store.receive(.second)
        store.receive(.second)
      } issueMatcher: { issue in
        issue.compactDescription == """
          Must handle 1 received action before sending an action: …

          Unhandled actions: [
            [0]: TestStoreFailureTests.Action.second
          ]
          """
      }
    }

    func testReceiveNonExistentActionFailure() {
      enum Action { case action }
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Action> { _, _ in .none }
      )

      XCTExpectFailure {
        store.receive(.action)
      } issueMatcher: { issue in
        issue.compactDescription == "Expected to receive an action, but received none."
      }
    }

    func testReceiveUnexpectedActionFailure() {
      enum Action { case first, second }
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Action> { state, action in
          switch action {
          case .first: return .init(value: .second)
          case .second: return .none
          }
        }
      )

      XCTExpectFailure {
        store.send(.first)
        store.receive(.first)
      } issueMatcher: { issue in
        issue.compactDescription == """
          Received unexpected action: …

              − TestStoreFailureTests.Action.first
              + TestStoreFailureTests.Action.second

          (Expected: −, Received: +)
          """
      }
    }

    func testModifyClosureThrowsErrorFailure() {
      let store = TestStore(
        initialState: 0,
        reducer: Reduce<Int, Void> { _, _ in .none }
      )

      XCTExpectFailure {
        _ = store.send(()) { _ in
          struct SomeError: Error {}
          throw SomeError()
        }
      } issueMatcher: { issue in
        issue.compactDescription == "Threw error: SomeError()"
      }
    }
  }
#endif
