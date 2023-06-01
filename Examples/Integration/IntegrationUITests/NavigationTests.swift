import Integration
import TestCases
import XCTest

@MainActor
final class NavigationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
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

  func testPopToRoot() {
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
    self.app.buttons["Pop to root"].tap()
    XCTAssertEqual(self.app.staticTexts["Root"].exists, true)
  }

  func testChildEffectsCancelOnDismiss() async throws {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Run effect"].tap()
    self.app.buttons["Root"].tap()
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Child response: 1"].exists, false)
  }

  func testChildViewIdentity() {
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["Has appeared"].exists, true)
    self.app.buttons["Recreate stack"].tap()
    XCTAssertEqual(self.app.staticTexts["Has appeared"].exists, true)
  }

  func testSimultaneousDismissAlertAndPop() async throws {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Show alert"].tap()
    self.app.buttons["Parent pops feature"].tap()
    try await Task.sleep(for: .seconds(1))
    XCTAssertEqual(self.app.staticTexts["What do you want to do?"].exists, false)
    try await Task.sleep(for: .seconds(1))
  }
}
