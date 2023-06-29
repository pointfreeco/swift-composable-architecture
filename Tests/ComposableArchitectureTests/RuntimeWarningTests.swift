#if DEBUG
  import Combine
  import ComposableArchitecture
  import XCTest

  final class RuntimeWarningTests: BaseTCATestCase {
    func testStoreCreationMainThread() {
      XCTExpectFailure {
        $0.compactDescription == """
          A store initialized on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """
      }

      Task {
        _ = Store<Int, Void>(initialState: 0) {}
      }
      _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }

    func testEffectFinishedMainThread() {
      XCTExpectFailure {
        $0.compactDescription == """
          An effect completed on a non-main thread. …

            Effect returned from:
              RuntimeWarningTests.Action.tap

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """
      }

      enum Action { case tap, response }
      let store = Store(initialState: 0) {
        Reduce<Int, Action> { state, action in
          switch action {
          case .tap:
            return Empty()
              .receive(on: DispatchQueue(label: "background"))
              .eraseToEffect()
          case .response:
            return .none
          }
        }
      }
      store.send(.tap)
      _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }

    func testStoreScopeMainThread() {
      XCTExpectFailure {
        [
          """
          "Store.scope" was called on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          """
          A store initialized on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """,
        ].contains($0.compactDescription)
      }

      let store = Store<Int, Void>(initialState: 0) {}
      Task {
        _ = store.scope(state: { $0 }, action: { $0 })
      }
      _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }

    func testViewStoreSendMainThread() {
      XCTExpectFailure {
        [
          """
          "ViewStore.send" was called on a non-main thread with: () …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """,
          """
          An effect completed on a non-main thread. …

            Effect returned from:
              ()

          Make sure to use ".receive(on:)" on any effects that execute on background threads to \
          receive their output on the main thread.

          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """,
        ].contains($0.compactDescription)
      }

      let store = Store<Int, Void>(initialState: 0) {}
      Task {
        store.send(())
      }
      _ = XCTWaiter.wait(for: [.init()], timeout: 0.5)
    }

    #if os(macOS)
      @MainActor
      func testEffectEmitMainThread() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
        XCTExpectFailure {
          [
            """
            An effect completed on a non-main thread. …

              Effect returned from:
                RuntimeWarningTests.Action.response

            Make sure to use ".receive(on:)" on any effects that execute on background threads to \
            receive their output on the main thread.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the main \
            thread.
            """,
            """
            An effect completed on a non-main thread. …

              Effect returned from:
                RuntimeWarningTests.Action.tap

            Make sure to use ".receive(on:)" on any effects that execute on background threads to \
            receive their output on the main thread.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the main \
            thread.
            """,
            """
            An effect published an action on a non-main thread. …

              Effect published:
                RuntimeWarningTests.Action.response

              Effect returned from:
                RuntimeWarningTests.Action.tap

            Make sure to use ".receive(on:)" on any effects that execute on background threads to \
            receive their output on the main thread.

            The "Store" class is not thread-safe, and so all interactions with an instance of \
            "Store" (including all of its scopes and derived view stores) must be done on the main \
            thread.
            """,
          ]
          .contains($0.compactDescription)
        }

        enum Action { case tap, response }
        let store = Store(initialState: 0) {
          Reduce<Int, Action> { state, action in
            switch action {
            case .tap:
              return .run { subscriber in
                Thread.detachNewThread {
                  XCTAssertFalse(Thread.isMainThread, "Effect should send on non-main thread.")
                  subscriber.send(.response)
                  subscriber.send(completion: .finished)
                }
                return AnyCancellable {}
              }
            case .response:
              return .none
            }
          }
        }
        await ViewStore(store, observe: { $0 }).send(.tap).finish()
      }
    #endif

    @MainActor
    func testBindingUnhandledAction() {
      struct State: Equatable {
        @BindingState var value = 0
      }
      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }
      let store = Store<State, Action>(initialState: State()) {}

      var line: UInt = 0
      XCTExpectFailure {
        line = #line
        ViewStore(store, observe: { $0 }).binding(\.$value).wrappedValue = 42
      } issueMatcher: {
        $0.compactDescription == """
          A binding action sent from a view store at "\(#fileID):\(line + 1)" was not handled. …

            Action:
              RuntimeWarningTests.Action.binding(.set(_, 42))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
      }
    }

    @MainActor
    func testBindingUnhandledAction_BindingState() {
      struct State: Equatable {
        @BindingState var value = 0
      }
      let line = #line - 2
      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }
      let store = Store<State, Action>(initialState: State()) {}

      XCTExpectFailure {
        ViewStore(store, observe: { $0 }).$value.wrappedValue = 42
      } issueMatcher: {
        $0.compactDescription == """
          A binding action sent from a view store for binding state defined at \
          "\(#fileID):\(line)" was not handled. …

            Action:
              RuntimeWarningTests.Action.binding(.set(_, 42))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
      }
    }
  }
#endif
