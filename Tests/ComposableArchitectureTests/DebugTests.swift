#if DEBUG
  import Combine
  import CustomDump
  import XCTest

  @testable import ComposableArchitecture

  final class DebugTests: XCTestCase {
    func testAlertState() {
      var dump = ""
      customDump(
        AlertState<Bool>(
          title: .init("Alert!"),
          message: .init("Something went wrong..."),
          primaryButton: .destructive(.init("Destroy"), action: .send(true, animation: .default)),
          secondaryButton: .cancel(.init("Cancel"), action: .send(false))
        ),
        to: &dump
      )
      XCTAssertEqual(
        dump,
        """
        AlertState(
          title: "Alert!",
          message: "Something went wrong...",
          buttons: [
            [0]: AlertState.Button.destructive(
              "Destroy",
              action: AlertState.ButtonAction.send(
                true,
                animation: Animation.easeInOut
              )
            ),
            [1]: AlertState.Button.cancel(
              "Cancel",
              action: AlertState.ButtonAction.send(false)
            )
          ]
        )
        """
      )

      if #available(iOS 13, macOS 12, tvOS 13, watchOS 6, *) {
        dump = ""
        customDump(
          ConfirmationDialogState<Bool>(
            title: .init("Alert!"),
            message: .init("Something went wrong..."),
            buttons: [
              .destructive(.init("Destroy"), action: .send(true, animation: .default)),
              .cancel(.init("Cancel"), action: .send(false)),
            ]
          ),
          to: &dump
        )
        XCTAssertEqual(
          dump,
          """
          ConfirmationDialogState(
            title: "Alert!",
            message: "Something went wrong...",
            buttons: [
              [0]: AlertState.Button.destructive(
                "Destroy",
                action: AlertState.ButtonAction.send(
                  true,
                  animation: Animation.easeInOut
                )
              ),
              [1]: AlertState.Button.cancel(
                "Cancel",
                action: AlertState.ButtonAction.send(false)
              )
            ]
          )
          """
        )
      }
    }

    func testTextState() {
      var dump = ""
      customDump(TextState("Hello, world!"), to: &dump)
      XCTAssertEqual(
        dump,
        """
        "Hello, world!"
        """
      )

      dump = ""
      customDump(
        TextState("Hello, ")
          + TextState("world").bold().italic()
          + TextState("!"),
        to: &dump
      )
      XCTAssertEqual(
        dump,
        """
        "Hello, _**world**_!"
        """
      )

      dump = ""
      customDump(
        TextState("Offset by 10.5").baselineOffset(10.5)
          + TextState("\n") + TextState("Headline").font(.headline)
          + TextState("\n") + TextState("No font").font(nil)
          + TextState("\n") + TextState("Light font weight").fontWeight(.light)
          + TextState("\n") + TextState("No font weight").fontWeight(nil)
          + TextState("\n") + TextState("Red").foregroundColor(.red)
          + TextState("\n") + TextState("No color").foregroundColor(nil)
          + TextState("\n") + TextState("Italic").italic()
          + TextState("\n") + TextState("Kerning of 2.5").kerning(2.5)
          + TextState("\n") + TextState("Stricken").strikethrough()
          + TextState("\n") + TextState("Stricken green").strikethrough(color: .green)
          + TextState("\n") + TextState("Not stricken blue").strikethrough(false, color: .blue)
          + TextState("\n") + TextState("Tracking of 5.5").tracking(5.5)
          + TextState("\n") + TextState("Underlined").underline()
          + TextState("\n") + TextState("Underlined pink").underline(color: .pink)
          + TextState("\n") + TextState("Not underlined purple").underline(false, color: .pink),
        to: &dump
      )
      XCTAssertEqual(
        dump,
        #"""
        """
        <baseline-offset=10.5>Offset by 10.5</baseline-offset>
        Headline
        No font
        <font-weight=light>Light font weight</font-weight>
        No font weight
        <foreground-color=red>Red</foreground-color>
        No color
        _Italic_
        <kerning=2.5>Kerning of 2.5</kerning>
        ~~Stricken~~
        <s color=green>Stricken green</s>
        Not stricken blue
        <tracking=5.5>Tracking of 5.5</tracking>
        <u>Underlined</u>
        <u color=pink>Underlined pink</u>
        Not underlined purple
        """
        """#
      )
    }

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
        @BindableState var width = 0
      }
      let action = BindingAction.set(\State.$width, 50)
      var dump = ""
      customDump(action, to: &dump)
      XCTAssertEqual(
        dump,
        #"""
        BindingAction.set(
          WritableKeyPath<State, BindableState<Int>>,
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
      let store = TestStore(initialState: 0, reducer: DebuggedReducer()._printChanges())
      store.dependencies.context = .preview
      await store.send(true) { $0 = 1 }
    }
  }
#endif
