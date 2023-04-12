import Integration
import TestCases
import XCTest

@MainActor
final class NavigationTests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    self.continueAfterFailure = false

    self.app = XCUIApplication()
    self.app.launch()
    self.app.collectionViews.buttons[TestCase.navigationStack.rawValue].tap()
  }

  func testChildLogic() {
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.app.buttons["Decrement"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
  }

  func testPushAndDismiss() {
    XCTAssertEqual(self.app.staticTexts["Root"].exists, true)
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.app.buttons["Go to counter: 1"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].exists, true)
    self.app.buttons["Go to counter: 2"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["3"].exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Root"].exists, true)
  }

  func testChildEffectsCancelOnDismiss() async throws {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Start"].tap()
    self.app.buttons["Back"].tap()
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Child response: 1"].exists, false)
  }
}
