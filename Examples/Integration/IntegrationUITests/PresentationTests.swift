import Integration
import TestCases
import XCTest

@MainActor
final class PresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.collectionViews.buttons[TestCase.presentation.rawValue].tap()
  }

  func testSheet_ChildDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, false)
  }

  func testSheet_ParentDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testSheet_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, false)

    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Count: 999"].exists, false)
  }

  func testSheet_IdentityChange() async throws {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Reset identity"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Count: 999"].exists, false)
  }

  func testPopover_ChildDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, false)
  }

  func testPopover_ParentDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testPopover_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, false)

    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Count: 999"].exists, false)
  }

  func testFullScreenCover_ChildDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, false)
  }

  func testFullScreenCover_ParentDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testFullScreenCover_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, false)

    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Count: 999"].exists, false)
  }

  func testAlertActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["OK"].tap()
    XCTAssertEqual(self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1), false)
  }

  func testAlertCancel() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Cancel"].tap()
    XCTAssertEqual(self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1), true)
  }

  func testAlertThenAlert() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show alert"].tap()
    XCTAssertEqual(self.app.staticTexts["Hello again!"].waitForExistence(timeout: 1), true)
  }

  func testAlertThenDialog() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show dialog"].tap()
    XCTAssertEqual(self.app.staticTexts["Hello!"].waitForExistence(timeout: 1), true)
  }

  func testAlertThenSheet() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show sheet"].tap()
    _ = self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1)
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
  }

  func testDialogActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["OK"].tap()
    XCTAssertEqual(self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1), false)
  }

  func testDialogCancel() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Cancel"].tap()
    XCTAssertEqual(self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1), true)
  }

  func testShowDialogThenAlert() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Show alert"].tap()
    XCTAssertEqual(self.app.staticTexts["Hello!"].waitForExistence(timeout: 1), true)
  }

  func testShowDialogThenDialog() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Show dialog"].tap()
    XCTAssertEqual(self.app.staticTexts["Hello again!"].waitForExistence(timeout: 1), true)
  }

  func testSheetExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open sheet"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }

  func testPopoverExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open popover"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }

  func testCoverExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }

  func testNavigationLink_ChildActions() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
  }

  func testNavigationLink_ChildDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testNavigationLink_ParentDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].tap()
    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testNavigationLink_ChildEffectCancellation() async throws {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].tap()
    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Parent dismiss"].tap()
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(
      self.app.staticTexts["Action sent while state nil."].exists,
      false
    )
  }

  func testNavigationLink_ExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }

  func testIdentifiedNavigationLink_ChildActions() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open identified navigation link"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
  }

  func testIdentifiedNavigationLink_NonDeadbeefLink() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open non-deadbeef identified navigation link"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testNavigationDestination_ChildDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, false)
  }

  func testNavigationDestination_ParentDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  func testNavigationDestination_EffectsCancelOnDismiss() async throws {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, false)

    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    try await Task.sleep(for: .seconds(3))
    XCTAssertEqual(self.app.staticTexts["Count: 999"].exists, false)
  }

  func testCustomAlert() async throws {
    self.app.buttons["Open custom alert"].tap()
    XCTAssertEqual(self.app.staticTexts["Custom alert!"].exists, true)
    self.app.typeText("Hello!")
    self.app.buttons["Submit"].tap()
    XCTAssertEqual(self.app.staticTexts["Hello!"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Dismiss action sent"].exists, true)
  }

  func testDismissAndAlert() async throws {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.app.buttons["Dismiss and alert"].tap()
    XCTTODO(
      """
      This test should pass but does not due to a SwiftUI bug. You cannot simultaneously close
      a sheet and open an alert.
      """
    )
    XCTAssertEqual(self.app.staticTexts["Alert open"].exists, true)
  }
}
