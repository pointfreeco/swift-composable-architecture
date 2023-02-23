import Combine
import CombineSchedulers
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

  func testRunFinish() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case responseBegin
      case response
      case responseEnd
      case tapEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
          await send(.tapEnd)
        }
      case .response:
        return .run { send in
          await send(.responseBegin)
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
      case .responseBegin, .responseEnd, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await store.receive(.responseBegin)
    await queue.advance(by: 1)
    await store.receive(.responseEnd)
    await store.receive(.tapEnd)
  }

  func testRunFinish_WithEffectOperators() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case responseEnd
      case tapEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
          await send(.tapEnd)
        }
        .map { $0 }
        .animation()
        .cancellable(id: 1)
        .concatenate(with: .none)
        .concatenate(with: .run(operation: { _ in }))
        .concatenate(with: .task { throw CancellationError() })
        .merge(with: .none)
        .merge(with: .run(operation: { _ in }))
        .merge(with: .task { throw CancellationError() })
        .transaction(.init())
      case .response:
        return .run { send in
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
      case .responseEnd, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await queue.advance(by: 1)
    await store.receive(.responseEnd)
    await store.receive(.tapEnd)
  }

  func testRunFinish_PublisherEffect() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case responseEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
        }
      case .response:
        return .run { send in
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
        .eraseToEffect()
      case .responseEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await queue.advance(by: 1)
    await store.receive(.responseEnd)
  }

  func testRunFinish_EffectOfEffect() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response1
      case response2
      case responseEnd
      case tapEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response1).finish()
          await send(.tapEnd)
        }
      case .response1:
        return .run { send in
          await send(.response2)
        }
      case .response2:
        return .run { send in
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
      case .responseEnd, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response1)
    await store.receive(.response2)
    await queue.advance(by: 1)
    await store.receive(.responseEnd)
    await store.receive(.tapEnd)
  }

  func testRunFinishNoTask() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case tapEnd
    }

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
          await send(.tapEnd)
        }
      case .response, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await store.receive(.tapEnd)
  }

  func testRunFinishCancellation() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case responseBegin
      case response
      case responseEnd
      case tapEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          let task = await send(.response)
          try await queue.sleep(for: 0.5)
          await task.cancel()
          await send(.tapEnd)
        }
      case .response:
        return .run { send in
          await send(.responseBegin)
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
      case .responseBegin, .responseEnd, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await store.receive(.responseBegin)
    await queue.advance(by: 0.5)
    await store.receive(.tapEnd)
  }

  func testRunFinishUnexpectedCancellation() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case responseBegin
      case response
      case responseEnded
      case tapEnd
    }

    let queue = DispatchQueue.test

    let isCancelled = ActorIsolated<Bool?>(nil)

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.response).finish()
          await send(.tapEnd)
          await isCancelled.setValue(Task.isCancelled)
        }
      case .response:
        return .run { send in
          await send(.responseBegin)
          try await queue.sleep(for: 1)
          await send(.responseEnded)
        }
      case .responseBegin, .responseEnded, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    let task = await store.send(.tap)
    await store.receive(.response)
    await store.receive(.responseBegin)
    await queue.advance(by: 0.5)
    await task.cancel()

    let wasCancelled = await isCancelled.value
    XCTAssertEqual(
      wasCancelled, true,
      "Cancelling `.tap` should cause `.response` to cancel and return."
    )
  }

  func testRunCancel() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case responseBegin
      case response
      case responseEnd
      case tapEnd
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          let task = await send(.response)
          try await queue.sleep(for: 0.5)
          await task.cancel()
          await send(.tapEnd)
        }
      case .response:
        return .run { send in
          await send(.responseBegin)
          try await queue.sleep(for: 1)
          await send(.responseEnd)
        }
      case .responseBegin, .responseEnd, .tapEnd:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await store.receive(.responseBegin)
    await queue.advance(by: 1)
    await store.receive(.tapEnd)
  }

  func testRun_FinishCancelledSend() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case responseEnded
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          let task = await send(.response)
          try await queue.sleep(for: 0.5)
          await task.cancel()
        }
      case .response:
        return .run { send in
          try? await queue.sleep(for: 1)
          await send(.responseEnded).finish()
        }
      case .responseEnded:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await queue.advance(by: 1)
    await store.finish()
  }

  func testRun_FinishCancelledSendWithTransaction() async {
    struct State: Equatable {}
    enum Action: Equatable {
      case tap
      case response
      case responseEnded
    }

    let queue = DispatchQueue.test

    let reducer = Reduce<State, Action> { state, action in
      switch action {
      case .tap:
        return .run { send in
          let task = await send(.response)
          try await queue.sleep(for: 0.5)
          await task.cancel()
        }
      case .response:
        return .run { send in
          try? await queue.sleep(for: 1)
          await send(.responseEnded, transaction: .init()).finish()
        }
      case .responseEnded:
        return .none
      }
    }

    let store = TestStore(initialState: .init(), reducer: reducer)

    await store.send(.tap)
    await store.receive(.response)
    await queue.advance(by: 1)
    await store.finish()
  }

  #if DEBUG
    func testRunFinishPublisherFailure() async {
      struct State: Equatable {}
      enum Action: Equatable {
        case tap
        case response
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect called 'EffectSendTask.finish()'. This method \
          no-ops if you apply any Combine operators to the Effect returned by \
          'EffectTask.run'.
          """
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            await send(.response).finish()
          }
          .eraseToEffect()
        case .response:
          return .none
        }
      }

      let store = TestStore(initialState: .init(), reducer: reducer)

      await store.send(.tap)
      await store.receive(.response)
    }

    func testRunCancelPublisherFailure() async {
      struct State: Equatable {}
      enum Action: Equatable {
        case tap
        case response
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect called 'EffectSendTask.cancel()'. This method \
          no-ops if you apply any Combine operators to the Effect returned by \
          'EffectTask.run'.
          """
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            await send(.response).cancel()
          }
          .eraseToEffect()
        case .response:
          return .none
        }
      }

      let store = TestStore(initialState: .init(), reducer: reducer)

      await store.send(.tap)
      await store.receive(.response)
    }

    func testRunIsCancelledPublisherFailure() async {
      struct State: Equatable {}
      enum Action: Equatable {
        case tap
        case response
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect accessed 'EffectSendTask.isCancelled'. This property \
          breaks if you apply any Combine operators to the Effect returned by \
          'EffectTask.run'.
          """
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            _ = await send(.response).isCancelled
          }
          .eraseToEffect()
        case .response:
          return .none
        }
      }

      let store = TestStore(initialState: .init(), reducer: reducer)

      await store.send(.tap)
      await store.receive(.response)
    }

    func testRunIsCheckCancellationPublisherFailure() async {
      struct State: Equatable {}
      enum Action: Equatable {
        case tap
        case response
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect accessed 'EffectSendTask.checkCancellation()'. This property \
          breaks if you apply any Combine operators to the Effect returned by \
          'EffectTask.run'.
          """
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            try await send(.response).checkCancellation()
          }
          .eraseToEffect()
        case .response:
          return .none
        }
      }

      let store = TestStore(initialState: .init(), reducer: reducer)

      await store.send(.tap)
      await store.receive(.response)
    }

    func testRunFinish_ParentErasesToEffect() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case tap
          case response
          case responseEnd
          case tapEnd
        }
        @Dependency(\.mainQueue) var mainQueue
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .tap:
            return .run { send in
              await send(.response).finish()
              await send(.tapEnd)
            }
          case .response:
            return .run { send in
              try await self.mainQueue.sleep(for: 1)
              await send(.responseEnd)
            }
          case .responseEnd, .tapEnd:
            return .none
          }
        }
      }

      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var child = Child.State()
        }
        enum Action: Equatable {
          case child(Child.Action)
        }
        var body: some ReducerProtocolOf<Self> {
          Scope(state: \.child, action: /Action.child) {
            Child()
          }
          Reduce<State, Action> { state, action in
            switch action {
            case .child(.tap):
              return .none.eraseToEffect()
            case .child:
              return .none
            }
          }
        }
      }

      let mainQueue = DispatchQueue.test
      let store = TestStore(initialState: Parent.State(), reducer: Parent()) {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A publisher-style Effect called 'EffectSendTask.finish()'. This method no-ops if you apply \
          any Combine operators to the Effect returned by 'EffectTask.run'.
          """
      }

      await store.send(.child(.tap))
      await store.receive(.child(.response))
      await store.receive(.child(.tapEnd))
      await mainQueue.advance(by: 1)
      await store.receive(.child(.responseEnd))
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
