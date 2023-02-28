import XCTest

@MainActor
final class ForEachBindingTests: XCTestCase {
  override func setUpWithError() throws {
    self.continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons["ForEachBindingTestCase"].tap()
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
