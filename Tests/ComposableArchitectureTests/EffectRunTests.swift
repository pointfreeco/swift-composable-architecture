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

  func testRunEscapeFailure() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case begin
      case beginPublisher
      case another
      case end
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .begin:
        return .run { send in
          Task { @MainActor in
            try await queue.sleep(for: 1)

            XCTExpectFailure {
              _ = send(.another)
            } issueMatcher: {
              $0.compactDescription == """
                  An action was sent from a completed effect.

                    Action:
                      TestReducer.TestAction(EffectRunTests.Action.another)

                    Effect returned from:
                      TestReducer.TestAction(EffectRunTests.Action.begin)

                  Avoid sending effects using the `send` closure passed to \
                  `EffectTask.run` after the effect has completed, because \
                  this makes it difficult to track the lifetime of the \
                  effect.

                  To fix this, make sure that your `run` closure does not \
                  return until you're done calling `send`.
                  """
            }
          }
          await send(.end)
        }
      case .beginPublisher:
        return .run { send in
          Task { @MainActor in
            try await queue.sleep(for: 1)

            XCTExpectFailure {
              _ = send(.another)
            } issueMatcher: {
              $0.compactDescription == """
                  An action was sent from a completed effect.

                    Action:
                      EffectRunTests.Action.another

                  Avoid sending effects using the `send` closure passed to \
                  `EffectTask.run` after the effect has completed, because \
                  this makes it difficult to track the lifetime of the \
                  effect.

                  To fix this, make sure that your `run` closure does not \
                  return until you're done calling `send`.
                  """
            }
          }
          await send(.end)
        }
        .eraseToAnyPublisher()
        .eraseToEffect()
      case .another, .end:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    let begin = await store.send(.begin)
    await store.receive(.end)
    await begin.finish()
    await queue.advance(by: 1)
    // we may or may not receive .another (specifically, we receive it in .begin but
    // not in .beginPublisher) but it doesn't matter because sending an action after
    // the effect ends is UB.
    await store.skipReceivedActions(strict: false)

    let beginPub = await store.send(.beginPublisher)
    await store.receive(.end)
    await beginPub.finish()
    await queue.advance(by: 1)
    await store.skipReceivedActions(strict: false)
  }
}
