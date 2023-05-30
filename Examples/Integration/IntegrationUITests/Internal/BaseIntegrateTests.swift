import XCTest

class BaseIntegrationTests: XCTestCase {
  var app: XCUIApplication!
  private var _expectRuntimeWarnings: (file: StaticString, line: UInt)?

  func expectRuntimeWarnings(file: StaticString = #file, line: UInt = #line) {
    self._expectRuntimeWarnings = (file, line)
  }

  override func tearDown() {
    super.tearDown()
    if let (file, line) = self._expectRuntimeWarnings {
      XCTAssert(
        self.app.staticTexts["Runtime warning"].waitForExistence(timeout: 1),
        "Expected runtime warning(s)",
        file: file,
        line: line
      )
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
