import Combine
import ComposableArchitecture
import XCTest

final class RuntimeWarningTests: XCTestCase {
  func testStoreCreationMainThread() {
    XCTExpectFailure {
      $0.compactDescription == """
        A store initialized on a non-main thread. …

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the main thread.
        """
    }

    Task {
      _ = Store<Int, Void>(initialState: 0, reducer: .empty, environment: ())
    }
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
  }

  func testEffectFinishedMainThread() {
    XCTExpectFailure {
      $0.compactDescription == """
        An effect completed on a non-main thread. …

          Effect returned from:
            Action.tap

        Make sure to use ".receive(on:)" on any effects that execute on background threads to \
        receive their output on the main thread.

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the main thread.
        """
    }

    enum Action { case tap, response }
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { state, action, _ in
        switch action {
        case .tap:
          return Empty()
            .receive(on: DispatchQueue(label: "background"))
            .eraseToEffect()
        case .response:
          return .none
        }
      },
      environment: ()
    )
    ViewStore(store).send(.tap)
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
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
        """
      ].contains($0.compactDescription)
    }

    let store = Store<Int, Void>(initialState: 0, reducer: .empty, environment: ())
    Task {
      _ = store.scope(state: { $0 })
    }
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
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
        """
      ].contains($0.compactDescription)
    }

    let store = Store(initialState: 0, reducer: Reducer<Int, Void, Void>.empty, environment: ())
    Task {
      ViewStore(store).send(())
    }
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
  }

  func testEffectEmitMainThread() {
    XCTExpectFailure {
      [
        """
        An effect completed on a non-main thread. …

          Effect returned from:
            Action.response

        Make sure to use ".receive(on:)" on any effects that execute on background threads to \
        receive their output on the main thread.

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the main thread.
        """,
        """
        An effect published an action on a non-main thread. …

          Effect published:
            Action.response

          Effect returned from:
            Action.tap

        Make sure to use ".receive(on:)" on any effects that execute on background threads to \
        receive their output on the main thread.

        The "Store" class is not thread-safe, and so all interactions with an instance of "Store" \
        (including all of its scopes and derived view stores) must be done on the main thread.
        """
      ]
        .contains($0.compactDescription)
    }

    enum Action { case tap, response }
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { state, action, _ in
        switch action {
        case .tap:
          return .run { subscriber in
            DispatchQueue(label: "background").async {
              subscriber.send(.response)
            }
            return AnyCancellable {
            }
          }
        case .response:
          return .none
        }
      },
      environment: ()
    )
    ViewStore(store).send(.tap)
    _ = XCTWaiter.wait(for: [.init()], timeout: 0.2)
  }

  func testBindingUnhandledAction() {
    struct State: Equatable {
      @BindableState var value = 0
    }
    enum Action: BindableAction, Equatable {
      case binding(BindingAction<State>)
    }
    let store = Store(
      initialState: .init(),
      reducer: Reducer<State, Action, ()>.empty,
      environment: ()
    )

    var line: UInt!
    XCTExpectFailure {
      line = #line
      ViewStore(store).binding(\.$value).wrappedValue = 42
    } issueMatcher: {
      $0.compactDescription == """
        A binding action sent from a view store at "ComposableArchitectureTests/RuntimeWarningTests.swift:\(line+1)" was not handled:

          Action:
            Action.binding(.set(_, 42))

        To fix this, invoke the "binding()" method on your feature's reducer.
        """
    }
  }
}
