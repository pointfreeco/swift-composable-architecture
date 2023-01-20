#if DEBUG
  import Combine
  import CustomDump
  import XCTest

  @testable import ComposableArchitecture

  final class DebugTests: XCTestCase {
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
      XCTAssertEqual(
        dump,
        #"""
        BindingAction.set(
          WritableKeyPath<State, BindingState<Int>>,
          50
        )
        """#
      )
    }

    @MainActor
    func testDebugReducer() async {
      struct DebuggedReducer: ReducerProtocol {
        typealias State = Int
        typealias Action = Bool
        func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
          state += action ? 1 : -1
          return .none
        }
      }

      let store = TestStore(initialState: 0, reducer: DebuggedReducer()._printChanges())
      await store.send(true) { $0 = 1 }
    }

    @MainActor
    func testDebugReducerInPreview() async {
      struct DebuggedReducer: ReducerProtocol {
        typealias State = Int
        typealias Action = Bool
        func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
          state += action ? 1 : -1
          return .none
        }
      }
      let store = TestStore(initialState: 0, reducer: DebuggedReducer()._printChanges()) {
        $0.context = .preview
      }
      await store.send(true) { $0 = 1 }
    }
  }
#endif
