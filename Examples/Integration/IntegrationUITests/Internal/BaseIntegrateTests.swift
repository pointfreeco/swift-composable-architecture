import XCTest

class BaseIntegrationTests: XCTestCase {
  var app: XCUIApplication!
  var expectRuntimeWarnings = false

  override func tearDown() {
    super.tearDown()
    if self.expectRuntimeWarnings {
      XCTAssertTrue(self.app.staticTexts["Runtime warning"].waitForExistence(timeout: 1))
    } else {
      XCTAssertFalse(self.app.staticTexts["Runtime warning"].exists)
    }
  }

  override func setUp() {
    self.continueAfterFailure = false
    self.app = XCUIApplication()
    self.app.launch()
  }
}
