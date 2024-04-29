import Combine
import ComposableArchitecture
import XCTest

final class EffectRunTests: BaseTCATestCase {
  @MainActor
  func testRun() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .run { send in await send(.response) }
        case .response:
          return .none
        }
      }
    }
    await store.send(.tapped)
    await store.receive(.response)
  }

  @MainActor
  func testRunCatch() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .run { _ in
            struct Failure: Error {}
            throw Failure()
          } catch: { _, send in
            await send(.response)
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
    @MainActor
    func testRunUnhandledFailure() async {
      var line: UInt!
      XCTExpectFailure(nil, enabled: nil, strict: nil) {
        $0.compactDescription == """
          An "Effect.run" returned from "\(#fileID):\(line+1)" threw an unhandled error. …

              EffectRunTests.Failure()

          All non-cancellation errors must be explicitly handled via the "catch" parameter on \
          "Effect.run", or via a "do" block.
          """
      }
      struct State: Equatable {}
      enum Action: Equatable { case tapped, response }
      let store = TestStore(initialState: State()) {
        Reduce<State, Action> { state, action in
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
      }
      // NB: We wait a long time here because XCTest failures take a long time to generate
      await store.send(.tapped).finish(timeout: 5 * NSEC_PER_SEC)
    }
  #endif

  @MainActor
  func testRunCancellation() async {
    enum CancelID { case response }
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .run { send in
            Task.cancel(id: CancelID.response)
            try Task.checkCancellation()
            await send(.response)
          }
          .cancellable(id: CancelID.response)
        case .response:
          return .none
        }
      }
    }
    await store.send(.tapped).finish()
  }

  @MainActor
  func testRunCancellationCatch() async {
    enum CancelID { case responseA }
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .tapped:
          return .run { send in
            Task.cancel(id: CancelID.responseA)
            try Task.checkCancellation()
            await send(.responseA)
          } catch: { _, send in
            await send(.responseB)
          }
          .cancellable(id: CancelID.responseA)
        case .responseA, .responseB:
          return .none
        }
      }
    }
    await store.send(.tapped).finish()
  }

  @MainActor
  func testRunEscapeFailure() async {
    XCTExpectFailure {
      $0.compactDescription == """
        An action was sent from a completed effect:

          Action:
            EffectRunTests.Action.response

          Effect returned from:
            EffectRunTests.Action.tap

        Avoid sending actions using the 'send' argument from 'Effect.run' after the effect has \
        completed. This can happen if you escape the 'send' argument in an unstructured context.

        To fix this, make sure that your 'run' closure does not return until you're done \
        calling 'send'.
        """
    }

    enum Action { case tap, response }

    let queue = DispatchQueue.test

    let store = Store(initialState: 0) {
      Reduce<Int, Action> { _, action in
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
    }

    let viewStore = ViewStore(store, observe: { $0 })
    await viewStore.send(.tap).finish()
    await queue.advance(by: .seconds(1))
  }
}
