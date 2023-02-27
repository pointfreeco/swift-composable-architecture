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
}
