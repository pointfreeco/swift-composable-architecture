import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectTaskTests: BaseTCATestCase {
  func testTask() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .task { .response }
        case .response:
          return .none
        }
      }
    }
    await store.send(.tapped)
    await store.receive(.response)
  }

  func testTaskCatch() async {
    struct State: Equatable {}
    enum Action: Equatable, Sendable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .task {
            struct Failure: Error {}
            throw Failure()
          } catch: { _ in
            .response
          }
        case .response:
          return .none
        }
      }
    }
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
      let store = TestStore(initialState: State()) {
        Reduce<State, Action> { state, action in
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
      }
      // NB: We wait a long time here because XCTest failures take a long time to generate
      await store.send(.tapped).finish(timeout: 5 * NSEC_PER_SEC)
    }
  #endif

  func testTaskCancellation() async {
    enum CancelID { case response }
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .task {
            Task.cancel(id: CancelID.response)
            try Task.checkCancellation()
            return .response
          }
          .cancellable(id: CancelID.response)
        case .response:
          return .none
        }
      }
    }
    await store.send(.tapped).finish()
  }

  func testTaskCancellationCatch() async {
    enum CancelID { case responseA }
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .task {
            Task.cancel(id: CancelID.responseA)
            try Task.checkCancellation()
            return .responseA
          } catch: { _ in
            .responseB
          }
          .cancellable(id: CancelID.responseA)
        case .responseA, .responseB:
          return .none
        }
      }
    }
    await store.send(.tapped).finish()
  }
}
