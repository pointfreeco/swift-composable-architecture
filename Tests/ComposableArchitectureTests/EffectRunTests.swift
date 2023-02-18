import Combine
import ComposableArchitecture
import XCTest
import CombineSchedulers

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

  func testRunFinish() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case begin
      case waitAck
      case wait
      case waitDone
      case end
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .begin:
        return .run { send in
          await send(.wait).finish()
          await send(.end)
        }
      case .wait:
        return .run { send in
          await send(.waitAck)
          try await queue.sleep(for: 1)
          await send(.waitDone)
        }
      case .waitAck, .waitDone, .end:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.begin)
    await store.receive(.wait)
    await store.receive(.waitAck)
    await queue.advance(by: 1)
    await store.receive(.waitDone)
    await store.receive(.end)
  }

  func testRunFinishNoTask() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case end
    }

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
          await send(.end)
        }
      case .response, .end:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await store.receive(.end)
  }

  func testRunFinishCancellation() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case begin
      case waitAck
      case wait
      case waitDone
      case end
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .begin:
        return .run { send in
          let task = await send(.wait)
          try await queue.sleep(for: 0.5)
          await task.cancel()
          await send(.end)
        }
      case .wait:
        return .run { send in
          await send(.waitAck)
          try await queue.sleep(for: 1)
          await send(.waitDone)
        }
      case .waitAck, .waitDone, .end:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.begin)
    await store.receive(.wait)
    await store.receive(.waitAck)
    await queue.advance(by: 0.5)
    await store.receive(.end)
  }

  func testRunFinishUnexpectedCancellation() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case begin
      case waitAck
      case wait
      case waitDone
      case end
    }

    let queue = DispatchQueue.test

    let ended = ActorIsolated(false)

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .begin:
        return .run { send in
          await send(.wait).finish()
          await send(.end)
          await ended.setValue(true)
        }
      case .wait:
        return .run { send in
          await send(.waitAck)
          try await queue.sleep(for: 1)
          await send(.waitDone)
        }
      case .waitAck, .waitDone, .end:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    let task = await store.send(.begin)
    await store.receive(.wait)
    await store.receive(.waitAck)
    await queue.advance(by: 0.5)
    await task.cancel()

    let hasEnded = await ended.value
    XCTAssert(hasEnded, "Cancelling `.begin` should cause `.wait` to cancel and return.")
  }

  #if DEBUG
    func testRunFinishPublisherFailure() async {
      struct State: Equatable {}
      enum Action: Equatable {
        case begin
        case waitAck
        case wait
        case waitDone
      }

      let queue = DispatchQueue.test

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect called 'EffectSendTask.finish()'. This method \
          no-ops if you apply any Combine operators to the Effect returned by \
          'EffectTask.run'.
          """
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .begin:
          return .run { send in
            await send(.wait).finish()
          }
          .eraseToEffect()
        case .wait:
          return .run { send in
            await send(.waitAck)
            try await queue.sleep(for: 1)
            await send(.waitDone)
          }
        case .waitAck, .waitDone:
          return .none
        }
      }

      let store = TestStore(initialState: .init(), reducer: reducer)

      await store.send(.begin)
      await store.receive(.wait)
      await store.receive(.waitAck)
      await queue.advance(by: 1)
      await store.receive(.waitDone)
    }

    func testRunEscapeFailure() async throws {
      XCTExpectFailure {
        $0.compactDescription == """
          An action was sent from a completed effect:

            Action:
              EffectRunTests.Action.response

            Effect returned from:
              EffectRunTests.Action.tap

          Avoid sending actions using the 'send' argument from 'EffectTask.run' after the effect has \
          completed. This can happen if you escape the 'send' argument in an unstructured context.

          To fix this, make sure that your 'run' closure does not return until you're done calling \
          'send'.
          """
      }

      enum Action { case tap, response }

      let queue = DispatchQueue.test

      let store = Store(
        initialState: 0,
        reducer: Reduce<Int, Action> { _, action in
          switch action {
          case .tap:
            return .run { send in
              Task(priority: .userInitiated) {
                try await queue.sleep(for: .seconds(1))
                await send(.response)
              }
            }
          case .response:
            return .none
          }
        }
      )

      let viewStore = ViewStore(store, observe: { $0 })
      await viewStore.send(.tap).finish()
      await queue.advance(by: .seconds(1))
    }

    func testRunEscapeFailurePublisher() async throws {
      XCTExpectFailure {
        $0.compactDescription == """
          An action was sent from a completed effect:

            Action:
              EffectRunTests.Action.response

          Avoid sending actions using the 'send' argument from 'EffectTask.run' after the effect has \
          completed. This can happen if you escape the 'send' argument in an unstructured context.

          To fix this, make sure that your 'run' closure does not return until you're done calling \
          'send'.
          """
      }

      enum Action { case tap, response }

      let queue = DispatchQueue.test

      let store = Store(
        initialState: 0,
        reducer: Reduce<Int, Action> { _, action in
          switch action {
          case .tap:
            return .run { send in
              Task(priority: .userInitiated) {
                try await queue.sleep(for: .seconds(1))
                await send(.response)
              }
            }
            .eraseToEffect()
          case .response:
            return .none
          }
        }
      )

      let viewStore = ViewStore(store, observe: { $0 })
      await viewStore.send(.tap).finish()
      await queue.advance(by: .seconds(1))
    }
  #endif
}
