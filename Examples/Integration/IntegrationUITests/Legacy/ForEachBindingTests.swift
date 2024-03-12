import TestCases
import XCTest

final class ForEachBindingTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
    app.collectionViews.buttons[TestCase.forEachBinding.rawValue].tap()
  }

  @MainActor
  func testExample() async throws {
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
