#if DEBUG
  import Combine
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class RuntimeWarningTests: BaseTCATestCase {
    @MainActor
    func testStoreCreationMainThread() async {
      uncheckedUseMainSerialExecutor = false
      XCTExpectFailure {
        $0.compactDescription == """
          A store initialized on a non-main thread. …

          The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
          (including all of its scopes and derived view stores) must be done on the main thread.
          """
      }

      _ = await Task.detached {
        _ = Store<Int, Void>(initialState: 0) {}
      }
      .value
    }

    @MainActor
    func testEffectFinishedMainThread() async throws {
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
            return .publisher {
              Empty()
                .receive(on: DispatchQueue(label: "background"))
            }
          case .response:
            return .none
          }
        }
      }
      await store.send(.tap).finish()
    }

    @MainActor
    func testStoreScopeMainThread() async {
      uncheckedUseMainSerialExecutor = false
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
      await Task.detached {
        _ = store.scope(state: \.self, action: \.self)
      }
      .value
    }

    @MainActor
    func testViewStoreSendMainThread() async {
      uncheckedUseMainSerialExecutor = false
      XCTExpectFailure {
        $0.compactDescription == """
          "Store.send" was called on a non-main thread with: () …

          The "Store" class is not thread-safe, and so all interactions with an instance of \
          "Store" (including all of its scopes and derived view stores) must be done on the main \
          thread.
          """
      }

      let store = Store<Int, Void>(initialState: 0) {}
      await Task.detached {
        _ = store.send(())
      }
      .value
    }

    @MainActor
    func testEffectEmitMainThread() async throws {
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
            return .publisher {
              Deferred {
                Future { callback in
                  callback(.success(.response))
                }
              }
              .receive(on: DispatchQueue(label: "background"))
            }
          case .response:
            return .none
          }
        }
      }
      await ViewStore(store, observe: { $0 }).send(.tap).finish()
    }

    @MainActor
    func testBindingUnhandledAction() {
      let line = #line + 2
      struct State: Equatable {
        @BindingState var value = 0
      }
      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }
      let store = Store<State, Action>(initialState: State()) {}

      XCTExpectFailure {
        ViewStore(store, observe: { $0 }).$value.wrappedValue = 42
      } issueMatcher: {
        $0.compactDescription == """
          A binding action sent from a store for binding state defined at \
          "\(#fileID):\(line)" was not handled. …

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
          A binding action sent from a store for binding state defined at \
          "\(#fileID):\(line)" was not handled. …

            Action:
              RuntimeWarningTests.Action.binding(.set(_, 42))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
      }
    }

    @Reducer
    struct TestStorePath_NotIntegrated {
      @ObservableState
      struct State: Equatable {
        var path = StackState<Int>()
      }
      enum Action {
        case path(StackAction<Int, Void>)
      }
    }
    @MainActor
    func testStorePath_NotIntegrated() {
      let store = Store(initialState: TestStorePath_NotIntegrated.State()) {
        TestStorePath_NotIntegrated()
      }

      XCTExpectFailure {
        store.scope(state: \.path, action: \.path)[fileID: "file.swift", line: 1] = .init()
      } issueMatcher: {
        $0.compactDescription == """
          SwiftUI wrote to a "NavigationStack" binding at "file.swift:1" with a path that has the \
          same number of elements that already exist in the store. SwiftUI should only write to \
          this binding with a path that has pushed a new element onto the stack, or popped one or \
          more elements from the stack.

          This usually means the "forEach" has not been integrated with the reducer powering the \
          store, and this reducer is responsible for handling stack actions.

          To fix this, ensure that "forEach" is invoked from the reducer's "body":

              Reduce { state, action in
                // ...
              }
              .forEach(\\.path, action: \\.path) {
                Path()
              }

          And ensure that every parent reducer is integrated into the root reducer that powers \
          the store.
          """
      }
    }

    @Reducer
    struct TestStoreDestination_NotIntegrated {
      @Reducer
      struct Destination {}
      @ObservableState
      struct State: Equatable {
        @Presents var destination: Destination.State?
      }
      enum Action {
        case destination(PresentationAction<Destination.Action>)
      }
    }
    @MainActor
    func testStoreDestination_NotIntegrated() {
      let store = Store(
        initialState: TestStoreDestination_NotIntegrated.State(destination: .init())
      ) {
        TestStoreDestination_NotIntegrated()
      }

      XCTExpectFailure {
        store[
          state: \.destination,
          action: \.destination,
          isInViewBody: false,
          fileID: "file.swift",
          line: 1
        ] = nil
      } issueMatcher: {
        $0.compactDescription == """
          SwiftUI dismissed a view through a binding at "file.swift:1", but the store destination \
          wasn't set to "nil".

          This usually means an "ifLet" has not been integrated with the reducer powering the \
          store, and this reducer is responsible for handling presentation actions.

          To fix this, ensure that "ifLet" is invoked from the reducer's "body":

              Reduce { state, action in
                // ...
              }
              .ifLet(\\.destination, action: \\.destination) {
                Destination()
              }

          And ensure that every parent reducer is integrated into the root reducer that powers the \
          store.
          """
      }
    }
  }
#endif
