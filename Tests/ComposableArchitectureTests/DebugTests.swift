import CustomDump
import Combine
import XCTest

@testable import ComposableArchitecture

final class DebugTests: XCTestCase {
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
      "Action.action1(_:, label:)"
    )

    XCTAssertEqual(
      debugCaseOutput(Action.action2(true, 1, "Blob")),
      "Action.action2(_:, _:, _:)"
    )

    XCTAssertEqual(
      debugCaseOutput(Action.screenA(.row(index: 1, action: .tapped))),
      "Action.screenA(.row(index:, action: .tapped))"
    )

    XCTAssertEqual(
      debugCaseOutput(Action.screenA(.row(index: 1, action: .textChanged(query: "Hi")))),
      "Action.screenA(.row(index:, action: .textChanged(query:)))"
    )
  }

  func testBindingAction() {
    var dump = ""
    customDump(BindingAction.set(\CGSize.width, 50), to: &dump)
    XCTAssertNoDifference(
      dump,
      #"""
      BindingAction.set(
        \CGSize.width,
        50.0
      )
      """#
    )
  }
}
