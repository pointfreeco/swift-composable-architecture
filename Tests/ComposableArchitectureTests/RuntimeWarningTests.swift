#if DEBUG
  import Combine
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class RuntimeWarningTests: BaseTCATestCase {
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
          failed - A binding action sent from a store for binding state defined at \
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
          failed - A binding action sent from a store for binding state defined at \
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
        store.scope(state: \.path, action: \.path)[
          fileID: "file.swift", filePath: "/file.swift", line: 1, column: 1
        ] = .init()
      } issueMatcher: {
        $0.compactDescription == """
          failed - A navigation stack binding at "file.swift:1" was written to with a path that \
          has the same number of elements that already exist in the store. A view should only \
          write to this binding with a path that has pushed a new element onto the stack, or \
          popped one or more elements from the stack.

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
          id: nil,
          state: \.destination,
          action: \.destination,
          isInViewBody: false,
          fileID: "file.swift",
          filePath: "/file.swift",
          line: 1,
          column: 1
        ] = nil
      } issueMatcher: {
        $0.compactDescription == """
          failed - A binding at "file.swift:1" was set to "nil", but the store destination wasn't \
          nil'd out.

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
