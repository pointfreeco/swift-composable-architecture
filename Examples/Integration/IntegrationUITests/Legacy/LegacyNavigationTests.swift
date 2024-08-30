import Integration
import TestCases
import XCTest

final class LegacyNavigationTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
    self.app.buttons[TestCase.Legacy.navigationStack.rawValue].tap()
  }

  @MainActor
  func testChildLogic() {
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.app.buttons["Decrement"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
  }

  @MainActor
  func testPushAndDismiss() {
    XCTAssertEqual(self.app.staticTexts["Root"].exists, true)
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].find().exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].find().exists, true)
    self.app.buttons["Go to counter: 1"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].find().exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].find().exists, true)
    self.app.buttons["Go to counter: 2"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].find().exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["3"].find().exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].find().exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].find().exists, true)
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Root"].find().exists, true)
  }

  @MainActor
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

  @MainActor
  func testChildEffectsCancelOnDismiss() {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Run effect"].tap()
    self.app.buttons["Root"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Child response: 1"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testChildViewIdentity() {
    self.app.buttons["Go to counter"].tap()
    XCTAssertEqual(self.app.staticTexts["Has appeared"].exists, true)
    self.app.buttons["Recreate stack"].tap()
    XCTAssertEqual(self.app.staticTexts["Has appeared"].exists, true)
  }

  @MainActor
  func testSimultaneousDismissAlertAndPop() async throws {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Show alert"].tap()
    self.app.buttons["Parent pops feature"].tap()
    try await Task.sleep(for: .seconds(1))
    XCTAssertEqual(self.app.staticTexts["What do you want to do?"].exists, false)
    try await Task.sleep(for: .seconds(1))
  }

  @MainActor
  func testNavigationDestination() async throws {
    self.app.buttons["Go to counter"].tap()
    self.app.buttons["Open navigation destination"].tap()
    XCTAssert(self.app.staticTexts["Destination"].exists)
  }
}
