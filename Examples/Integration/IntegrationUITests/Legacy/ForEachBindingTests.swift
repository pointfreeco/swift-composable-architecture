import TestCases
import XCTest

@MainActor
final class ForEachBindingTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
  }

  func testExample() async throws {
    app.collectionViews.buttons[TestCase.forEachBinding.rawValue].tap()
    app.buttons["Remove last"].tap()
    XCTAssertFalse(app.textFields["C"].exists)
    app.buttons["Remove last"].tap()
    XCTAssertFalse(app.textFields["B"].exists)
    app.buttons["Remove last"].tap()
    XCTAssertFalse(app.textFields["A"].exists)

    XCTExpectFailure(
      """
        This ideally would not fail, but currently does. See this PR for more details:

        https://github.com/pointfreeco/swift-composable-architecture/pull/1845
      """
    ) {
      XCTAssertFalse(app.staticTexts["🛑"].exists)
    }
  }
}
