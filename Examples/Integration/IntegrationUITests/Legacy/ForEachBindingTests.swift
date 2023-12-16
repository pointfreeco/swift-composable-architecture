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
    XCTAssertFalse(app.staticTexts["🛑"].exists)
  }
}
