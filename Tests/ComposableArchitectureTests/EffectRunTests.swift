import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectRunTests: XCTestCase {
  func testRun() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tapped:
        return .run { send in await send(.response) }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped)
    await store.receive(.response)
  }

  func testRunCatch() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tapped:
        return .run { _ in
          struct Failure: Error {}
          throw Failure()
        } catch: { @Sendable _, send in  // NB: Explicit '@Sendable' required in 5.5.2
          await send(.response)
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
    func testRunUnhandledFailure() async {
      var line: UInt!
      XCTExpectFailure(nil, enabled: nil, strict: nil) {
        $0.compactDescription == """
          An "EffectTask.run" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectRunTests.Failure()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "EffectTask.run", or via a "do" block.
          """
      }
      struct State: Equatable {}
      enum Action: Equatable { case tapped, response }
      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          line = #line
          return .run { send in
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

  func testRunCancellation() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tapped:
        return .run { send in
          Task.cancel(id: CancelID.self)
          try Task.checkCancellation()
          await send(.response)
        }
        .cancellable(id: CancelID.self)
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer)
    await store.send(.tapped).finish()
  }

  func testRunCancellationCatch() async {
    enum CancelID {}
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tapped:
        return .run { send in
          Task.cancel(id: CancelID.self)
          try Task.checkCancellation()
          await send(.responseA)
        } catch: { @Sendable _, send in  // NB: Explicit '@Sendable' required in 5.5.2
          await send(.responseB)
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
