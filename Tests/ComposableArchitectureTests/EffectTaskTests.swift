import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectTaskTests: XCTestCase {
  func testTask() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tapped:
        return .task { .response }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped)
    await store.receive(.response)
  }

  func testTaskCatch() async {
    struct State: Equatable {}
    enum Action: Equatable, Sendable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
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
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped)
    await store.receive(.response)
  }

  #if DEBUG
    func testTaskUnhandledFailure() async {
      var line: UInt!
      XCTExpectFailure(nil, enabled: nil, strict: nil) {
        $0.compactDescription == """
          An "EffectTask.task" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectTaskTests.Failure()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "EffectTask.task", or via a "do" block.
          """
      }
      struct State: Equatable {}
      enum Action: Equatable { case tapped, response }
      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          line = #line
          return .task {
            struct Failure: Error {}
            throw Failure()
          }
        case .response:
          return .none
        }
      }
      let store = TestStore(initialState: State(), reducer: reducer)
      // NB: We wait a long time here because XCTest failures take a long time to generate
      await store.send(.tapped).finish(timeout: 5 * NSEC_PER_SEC)
    }
  #endif

  func testTaskCancellation() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
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
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped).finish()
  }

  func testTaskCancellationCatch() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let reducer = Reduce<State, Action> { state, action in
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
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped).finish()
  }
}
