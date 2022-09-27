import Combine
import XCTest

@testable import ComposableArchitecture

@MainActor
final class EffectTaskTests: XCTestCase {
  func testTask() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .task { .response }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped)
    await store.receive(.response)
  }

  func testTaskCatch() async {
    struct State: Equatable {}
    enum Action: Equatable, Sendable { case tapped, response }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .task {
          struct Failure: Error {}
          throw Failure()
        } catch: { @Sendable _ in  // NB: Explicit '@Sendable' required in 5.5.2
          .response
        }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped)
    await store.receive(.response)
  }

  func testTaskUnhandledFailure() async {
    XCTExpectFailure(nil, enabled: nil, strict: nil) {
      $0.compactDescription == """
        An 'Effect.task' returned from "ComposableArchitectureTests/EffectTaskTests.swift:62" \
        threw an unhandled error. …

            EffectTaskTests.Failure()

        All non-cancellation errors must be explicitly handled via the 'catch' parameter on \
        'Effect.task', or via a 'do' block.
        """
    }
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .task {
          struct Failure: Error {}
          throw Failure()
        }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    // NB: We wait a long time here because XCTest failures take a long time to generate
    await store.send(.tapped).finish(timeout: 5 * NSEC_PER_SEC)
  }

  func testTaskCancellation() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .task {
          Task.cancel(id: CancelID.self)
          try Task.checkCancellation()
          return .response
        }
        .cancellable(id: CancelID.self)
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped).finish()
  }

  func testTaskCancellationCatch() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .task {
          Task.cancel(id: CancelID.self)
          try Task.checkCancellation()
          return .responseA
        } catch: { @Sendable _ in  // NB: Explicit '@Sendable' required in 5.5.2
          .responseB
        }
        .cancellable(id: CancelID.self)
      case .responseA, .responseB:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped).finish()
  }
}
