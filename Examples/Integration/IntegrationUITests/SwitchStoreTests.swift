import Integration
import TestCases
import XCTest

@MainActor
final class SwitchStoreTests: XCTestCase {
  override func setUpWithError() throws {
    self.continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons[TestCase.switchStore.rawValue].tap()

    XCTAssertFalse(app.staticTexts["Warning"].exists)

    app.buttons["Swap"].tap()

    XCTAssertTrue(
      app.staticTexts
        .containing(NSPredicate(format: #"label CONTAINS[c] "Warning: ""#))
        .element
        .exists
    )
  }
}
