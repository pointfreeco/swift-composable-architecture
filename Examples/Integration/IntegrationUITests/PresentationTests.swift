import Integration
import TestCases
import XCTest

@MainActor
final class PresentationTests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    self.continueAfterFailure = false

    self.app = XCUIApplication()
    self.app.launch()
    self.app.collectionViews.buttons[TestCase.presentation.rawValue].tap()
  }

  func testSheet_ChildDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 2"].exists)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 2"].exists)
  }

  func testSheet_ParentDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 0"].exists)
  }

  func testSheet_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(false, self.app.staticTexts["Count: 999"].exists)
  }

  func testSheet_IdentityChange() async throws {
    // TODO: Remove this XCTExpectFailure once the destination identifiable problem is fixed.
    XCTExpectFailure()

    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Reset identity"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)

    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(false, self.app.staticTexts["Count: 999"].exists)
  }

  func testPopover_ChildDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 2"].exists)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 2"].exists)
  }

  func testPopover_ParentDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 0"].exists)
  }

  func testPopover_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(false, self.app.staticTexts["Count: 999"].exists)
  }

  func testFullScreenCover_ChildDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 2"].exists)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 2"].exists)
  }

  func testFullScreenCover_ParentDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 0"].exists)
  }

  func testFullScreenCover_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(false, self.app.staticTexts["Count: 1"].exists)

    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(true, self.app.staticTexts["Count: 0"].exists)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(false, self.app.staticTexts["Count: 999"].exists)
  }

  func testAlertActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["OK"].tap()
    _ = self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1)
    XCTAssertEqual(false, self.app.staticTexts["Dismiss action sent"].exists)
  }

  func testAlertCancel() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Cancel"].tap()
    _ = self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1)
    XCTAssertEqual(true, self.app.staticTexts["Dismiss action sent"].exists)
  }

  func testAlertThenDialog() {
    // TODO: Remove this XCTExpectFailure once the destination identifiable problem is fixed.
    XCTExpectFailure()

    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show dialog"].tap()
    _ = self.app.staticTexts["Hello!"].waitForExistence(timeout: 1)
    XCTAssertEqual(true, self.app.staticTexts["Hello!"].exists)
  }

  func testDialogActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["OK"].tap()
    _ = self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1)
    XCTAssertEqual(false, self.app.staticTexts["Dismiss action sent"].exists)
  }

  func testDialogCancel() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Cancel"].tap()
    _ = self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1)
    XCTAssertEqual(true, self.app.staticTexts["Dismiss action sent"].exists)
  }

  func testShowDialogThenAlert() {
    // TODO: Remove this XCTExpectFailure once the destination identifiable problem is fixed.
    XCTExpectFailure()

    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Show alert"].tap()
    _ = self.app.staticTexts["Hello!"].waitForExistence(timeout: 1)
    XCTAssertEqual(true, self.app.staticTexts["Hello!"].exists)
  }

  func testExtraBindingActionsIgnoredOnDismiss() {
    // TODO: Remove this XCTExpectFailure once the binding-in-sheet bug is fixed
    XCTExpectFailure()

    self.app.buttons["Open sheet"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }
}
