import Integration
import XCTest
import TestCases

@MainActor
final class PresentationTests: XCTestCase {
  override func setUpWithError() throws {
    self.continueAfterFailure = false
  }

  func testPresentation() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons[TestCase.presentation.rawValue].tap()

    app.buttons["Open child"].tap()
    XCTAssertEqual(true, app.staticTexts["Count: 0"].exists)

    app.buttons["Increment"].tap()
    XCTAssertEqual(true, app.staticTexts["Count: 1"].exists)
    app.buttons["Increment"].tap()
    XCTAssertEqual(true, app.staticTexts["Count: 2"].exists)

    app.buttons["Child dismiss"].tap()
    XCTAssertEqual(false, app.staticTexts["Count: 2"].exists)

    app.buttons["Open child"].tap()
    XCTAssertEqual(true, app.staticTexts["Count: 0"].exists)

    app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, app.staticTexts["Count: 0"].exists)
  }
}
