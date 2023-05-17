import XCTest

class BaseIntegrationTests: XCTestCase {
  var app: XCUIApplication!

  override func tearDown() {
    super.tearDown()
    XCTAssertEqual(self.app.staticTexts["Runtime warning"].exists, false)
  }

  override func setUp() {
    self.continueAfterFailure = false
    self.app = XCUIApplication()
    self.app.launch()
  }
}
