import ComposableArchitecture
import XCTest

final class TestStoreFailureTests: BaseTCATestCase {
  @MainActor
  func testNoStateChangeFailure() async {
    enum Action { case first, second }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .first: return .send(.second)
        case .second: return .none
        }
      }
    }

    XCTExpectFailure {
      $0.compactDescription == """
        Expected state to change, but no change occurred.

        The trailing closure made no observable modifications to state. If no change to state is \
        expected, omit the trailing closure.
        """
    }
    await store.send(.first) { _ = $0 }

    XCTExpectFailure {
      $0.compactDescription == """
        Expected state to change, but no change occurred.

        The trailing closure made no observable modifications to state. If no change to state is \
        expected, omit the trailing closure.
        """
    }
    await store.receive(.second) { _ = $0 }
  }

  @MainActor
  func testStateChangeFailure() async {
    struct State: Equatable { var count = 0 }
    let store = TestStore(initialState: State()) {
      Reduce<State, Void> { state, action in
        state.count += 1
        return .none
      }
    }

    XCTExpectFailure {
      $0.compactDescription == """
        A state change does not match expectation: …

            − TestStoreFailureTests.State(count: 0)
            + TestStoreFailureTests.State(count: 1)

        (Expected: −, Actual: +)
        """
    }
    await store.send(()) { $0.count = 0 }
  }

  @MainActor
  func testUnexpectedStateChangeOnSendFailure() async {
    struct State: Equatable { var count = 0 }
    let store = TestStore(initialState: State()) {
      Reduce<State, Void> { state, action in
        state.count += 1
        return .none
      }
    }

    XCTExpectFailure {
      $0.compactDescription == """
        State was not expected to change, but a change occurred: …

            − TestStoreFailureTests.State(count: 0)
            + TestStoreFailureTests.State(count: 1)

        (Expected: −, Actual: +)
        """
    }
    await store.send(())
  }

  @MainActor
  func testUnexpectedStateChangeOnReceiveFailure() async {
    struct State: Equatable { var count = 0 }
    enum Action { case first, second }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .first: return .send(.second)
        case .second:
          state.count += 1
          return .none
        }
      }
    }

    await store.send(.first)
    XCTExpectFailure {
      $0.compactDescription == """
        State was not expected to change, but a change occurred: …

            − TestStoreFailureTests.State(count: 0)
            + TestStoreFailureTests.State(count: 1)

        (Expected: −, Actual: +)
        """
    }
    await store.receive(.second)
  }

  @MainActor
  func testReceivedActionAfterDeinit() async {
    enum Action { case first, second }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .first: return .send(.second)
        case .second: return .none
        }
      }
    }

    XCTExpectFailure {
      $0.compactDescription == """
        The store received 1 unexpected action by the end of this test: …

          Unhandled actions:
            • .second
        """
    }
    await store.send(.first)
  }

  @MainActor
  func testEffectInFlightAfterDeinit() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Void> { state, action in
        .run { _ in try await Task.never() }
      }
    }

    XCTExpectFailure {
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
    await store.send(())
  }

  @MainActor
  func testSendActionBeforeReceivingFailure() async {
    enum Action { case first, second }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .first: return .send(.second)
        case .second: return .none
        }
      }
    }

    await store.send(.first)

    XCTExpectFailure {
      $0.compactDescription == """
        Must handle 1 received action before sending an action: …

        Unhandled actions: [
          [0]: .second
        ]
        """
    }
    await store.send(.first)

    await store.receive(.second)
    await store.receive(.second)
  }

  @MainActor
  func testReceiveNonExistentActionFailure() async {
    enum Action { case action }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { _, _ in .none }
    }

    XCTExpectFailure {
      $0.compactDescription == """
        Expected to receive the following action, but didn't: …

          TestStoreFailureTests.Action.action
        """
    }
    await store.receive(.action)
  }

  @MainActor
  func testReceiveUnexpectedActionFailure() async {
    enum Action { case first, second }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .first:
          return .send(.second)
        case .second:
          state += 1
          return .none
        }
      }
    }

    await store.send(.first)

    XCTExpectFailure {
      $0.compactDescription == """
        Received unexpected action: …

            − TestStoreFailureTests.Action.first
            + TestStoreFailureTests.Action.second

        (Expected: −, Received: +)
        """
    }
    await store.receive(.first)
  }

  @MainActor
  func testModifyClosureThrowsErrorFailure() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Void> { _, _ in .none }
    }

    XCTExpectFailure {
      $0.compactDescription == "Threw error: SomeError()"
    }
    await store.send(()) { _ in
      struct SomeError: Error {}
      throw SomeError()
    }
  }

  @MainActor
  func testExpectedStateEqualityMustModify() async {
    let store = TestStore(initialState: 0) {
      Reduce<Int, Bool> { state, action in
        switch action {
        case true: return .send(false)
        case false: return .none
        }
      }
    }

    await store.send(true)
    await store.receive(false)

    XCTExpectFailure()
    await store.send(true) {
      $0 = 0
    }

    XCTExpectFailure()
    await store.receive(false) {
      $0 = 0
    }
  }
}
