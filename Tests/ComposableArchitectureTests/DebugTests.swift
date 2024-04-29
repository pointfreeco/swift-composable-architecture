#if DEBUG
  import Combine
  import CustomDump
  import XCTest

  @testable import ComposableArchitecture

  final class DebugTests: BaseTCATestCase {
    func testDebugCaseOutput() {
      enum Action {
        case action1(Bool, label: String)
        case action2(Bool, Int, String)
        case screenA(ScreenA)

        enum ScreenA {
          case row(index: Int, action: RowAction)

          enum RowAction {
            case tapped
            case textChanged(query: String)
          }
        }
      }

      XCTAssertEqual(
        debugCaseOutput(Action.action1(true, label: "Blob")),
        "DebugTests.Action.action1(_:, label:)"
      )

      XCTAssertEqual(
        debugCaseOutput(Action.action2(true, 1, "Blob")),
        "DebugTests.Action.action2(_:, _:, _:)"
      )

      XCTAssertEqual(
        debugCaseOutput(Action.screenA(.row(index: 1, action: .tapped))),
        "DebugTests.Action.screenA(.row(index:, action: .tapped))"
      )

      XCTAssertEqual(
        debugCaseOutput(Action.screenA(.row(index: 1, action: .textChanged(query: "Hi")))),
        "DebugTests.Action.screenA(.row(index:, action: .textChanged(query:)))"
      )
    }

    func testBindingAction() {
      struct State {
        @BindingState var width = 0
      }
      let action = BindingAction.set(\State.$width, 50)
      var dump = ""
      customDump(action, to: &dump)

      #if swift(>=5.9)
        XCTAssertEqual(
          dump,
          #"""
          .set(\State.$width, 50)
          """#
        )
      #else
        XCTAssertEqual(
          dump,
          #"""
          .set(WritableKeyPath<DebugTests.State, BindingState<Int>>, 50)
          """#
        )
      #endif
    }

    func testBindingAction_Nested() {
      struct Settings: Equatable {
        var isEnabled = false
        var description = ""
      }
      struct State {
        @BindingState var settings = Settings()
      }
      let action = BindingAction.set(\State.$settings, Settings(isEnabled: true))
      var dump = ""
      customDump(action, to: &dump)

      #if swift(>=5.9)
        XCTAssertEqual(
          dump,
          #"""
          .set(\State.$settings, DebugTests.Settings(…))
          """#
        )
      #else
        XCTAssertEqual(
          dump,
          #"""
          .set(WritableKeyPath<DebugTests.State, BindingState<DebugTests.Settings>>, DebugTests.Settings(…))
          """#
        )
      #endif
    }

    @MainActor
    func testDebugReducer() async throws {
      let logs = LockIsolated<String>("")
      let printer = _ReducerPrinter<Int, Bool>(
        printChange: { action, oldState, newState in
          logs.withValue { _ = dump(action, to: &$0) }
        }
      )

      let store = Store<Int, Bool>(initialState: 0) {
        Reduce<Int, Bool>(internal: { state, action in
          state += action ? 1 : -1
          return .none
        })
        ._printChanges(printer)
      }
      store.send(true)
      try await Task.sleep(nanoseconds: 300_000_000)
      XCTAssertNoDifference(
        logs.value,
        """
        - true

        """
      )
    }

    func testDebugReducer_Order() {
      let logs = LockIsolated<String>("")
      let printer = _ReducerPrinter<Int, Bool>(
        printChange: { action, oldState, newState in
          logs.withValue { _ = dump(action, to: &$0) }
        }
      )

      let store = Store<Int, Bool>(initialState: 0) {
        Reduce<Int, Bool>(internal: { state, action in
          state += action ? 1 : -1
          return .run { _ in await Task.yield() }
        })
        ._printChanges(printer)
        ._printChanges(printer)
        ._printChanges(printer)
        ._printChanges(printer)
      }
      store.send(true)
      store.send(false)
      store.send(true)
      store.send(false)
      _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: 0.3)
      XCTAssertNoDifference(
        logs.value,
        """
        - true
        - true
        - true
        - true
        - false
        - false
        - false
        - false
        - true
        - true
        - true
        - true
        - false
        - false
        - false
        - false

        """
      )
    }

    @MainActor
    func testDebugReducer_SharedState() async throws {
      let logs = LockIsolated<String>("")
      let printer = _ReducerPrinter<State, Bool>(
        printChange: { action, oldState, newState in
          logs.withValue {
            $0.append(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
          }
        }
      )

      struct State {
        @Shared var count: Int
      }

      let store = Store<State, Bool>(initialState: State(count: Shared(0))) {
        Reduce<State, Bool>(internal: { state, action in
          state.count += action ? 1 : -1
          return .none
        })
        ._printChanges(printer)
      }
      store.send(true)
      try await Task.sleep(nanoseconds: 300_000_000)
      XCTAssertNoDifference(
        logs.value,
        #"""
          DebugTests.State(
        -   _count: #1 0
        +   _count: #1 1
          )

        """#
      )
    }
  }
#endif
