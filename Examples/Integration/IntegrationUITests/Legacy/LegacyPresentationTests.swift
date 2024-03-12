import Integration
import TestCases
import XCTest

final class LegacyPresentationTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
    self.app.buttons[TestCase.presentation.rawValue].tap()
  }

  @MainActor
  func testSheet_ChildDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 2"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testSheet_ParentDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testSheet_EffectsCancelOnDismiss() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 1"].waitForExistence(timeout: 1),
      false
    )

    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    XCTAssertEqual(
      self.app.staticTexts["Count: 999"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testSheet_IdentityChange() {
    self.app.buttons["Open sheet"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Reset identity"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    XCTAssertEqual(
      self.app.staticTexts["Count: 999"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testPopover_ChildDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 2"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testPopover_ParentDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testPopover_EffectsCancelOnDismiss() {
    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 1"].waitForExistence(timeout: 1),
      false
    )

    self.app.buttons["Open popover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    XCTAssertEqual(
      self.app.staticTexts["Count: 999"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testFullScreenCover_ChildDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 2"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testFullScreenCover_ParentDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testFullScreenCover_EffectsCancelOnDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 1"].waitForExistence(timeout: 1),
      false
    )

    self.app.buttons["Open full screen cover"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    XCTAssertEqual(
      self.app.staticTexts["Count: 999"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testAlertActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["OK"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testAlertCancel() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Cancel"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testAlertThenAlert() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show alert"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Hello again!"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testAlertThenDialog() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show dialog"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Hello!"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testAlertThenSheet() {
    self.app.buttons["Open alert"].tap()
    self.app.buttons["Show sheet"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testDialogActionDoesNotSendExtraDismiss() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["OK"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testDialogCancel() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Cancel"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testShowDialogThenAlert() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Show alert"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Hello!"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testShowDialogThenDialog() {
    self.app.buttons["Open dialog"].tap()
    self.app.buttons["Show dialog"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Hello again!"].waitForExistence(timeout: 1),
      true
    )
  }

  @MainActor
  func testSheetExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open sheet"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Action sent while state nil."].exists,
      false
    )
  }

  @MainActor
  func testPopoverExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open popover"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Action sent while state nil."].exists,
      false
    )
  }

  @MainActor
  func testCoverExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open full screen cover"].tap()
    self.app.textFields["Text field"].tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Action sent while state nil."].exists,
      false
    )
  }

  @MainActor
  func testNavigationLink_ChildActions() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].find().tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 1"].exists,
      true
    )
  }

  @MainActor
  func testNavigationLink_ChildDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].find().tap()
    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testNavigationLink_ParentDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].find().tap()
    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testNavigationLink_ChildEffectCancellation() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].find().tap()
    self.app.buttons["Start effect"].find().tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Action sent while state nil."].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testNavigationLink_ExtraBindingActionsIgnoredOnDismiss() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open navigation link"].find().tap()
    self.app.textFields["Text field"].find().tap()
    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Action sent while state nil."].exists, false)
  }

  @MainActor
  func testIdentifiedNavigationLink_ChildActions() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open identified navigation link"].find().tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
  }

  @MainActor
  func testIdentifiedNavigationLink_NonDeadbeefLink() {
    self.app.buttons["Open navigation link demo"].tap()
    self.app.buttons["Open non-deadbeef identified navigation link"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)
  }

  @MainActor
  func testNavigationDestination_ChildDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 2"].exists, true)

    self.app.buttons["Child dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 2"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testNavigationDestination_ParentDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 0"].waitForExistence(timeout: 1),
      false
    )
  }

  @MainActor
  func testNavigationDestination_BackButtonDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.navigationBars.buttons.element.tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, false)

    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
  }

  @MainActor
  func testNavigationDestination_EffectsCancelOnDismiss() {
    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)

    self.app.buttons["Start effect"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)

    self.app.buttons["Parent dismiss"].tap()
    XCTAssertEqual(
      self.app.staticTexts["Count: 1"].waitForExistence(timeout: 1),
      false
    )

    self.app.buttons["Open navigation destination"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    XCTAssertEqual(
      app.staticTexts["Count: 999"].waitForExistence(timeout: 3),
      false
    )
  }

  @MainActor
  func testCustomAlert() {
    app.buttons["Open custom alert"].tap()
    XCTAssertEqual(app.staticTexts["Custom alert!"].exists, true)
    app.typeText("Hello!")
    app.buttons["Submit"].tap()
    XCTAssertEqual(app.staticTexts["Hello!"].waitForExistence(timeout: 1), true)
    XCTAssertEqual(app.staticTexts["Dismiss action sent"].waitForExistence(timeout: 1), true)
  }

  @MainActor
  func testDismissAndAlert() {
    app.buttons["Open sheet"].tap()
    XCTAssertEqual(app.staticTexts["Count: 0"].exists, true)
    app.buttons["Dismiss and alert"].tap()
    XCTTODO(
      """
      This test should pass but does not due to a SwiftUI bug. You cannot simultaneously close
      a sheet and open an alert.
      """
    )
    XCTAssertEqual(self.app.staticTexts["Alert open"].exists, true)
  }
}
