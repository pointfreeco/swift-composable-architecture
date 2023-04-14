import Combine
import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import XCTest

@MainActor
final class EffectRunTests: BaseTCATestCase {
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
      await _withMainSerialExecutor {
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

  #if DEBUG
    func testRunEscapeFailure() async throws {
      try await _withMainSerialExecutor {
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
