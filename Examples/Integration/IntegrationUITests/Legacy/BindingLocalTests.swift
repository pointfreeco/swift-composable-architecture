import TestCases
import XCTest

@MainActor
final class BindingLocalTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
    app.collectionViews.buttons[TestCase.bindingLocal.rawValue].tap()
  }

  func testNoBindingWarning_FullScreenCover() {
    app.buttons["Full-screen-cover"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning_FullScreenCover() {
    self.expectRuntimeWarnings()

    app.buttons["Full-screen-cover"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testNoBindingWarning_NavigationDestination() {
    app.buttons["Navigation destination"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning_NavigationDestination() {
    self.expectRuntimeWarnings()

    app.buttons["Navigation destination"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testNoBindingWarning_Path() {
    app.buttons["Path"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning_Path() {
    self.expectRuntimeWarnings()

    app.buttons["Path"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testNoBindingWarning_Popover() {
    app.buttons["Popover"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning_Popover() {
    self.expectRuntimeWarnings()

    app.buttons["Popover"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testNoBindingWarning_Sheet() {
    app.buttons["Sheet"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning_Sheet() {
    self.expectRuntimeWarnings()

    app.buttons["Sheet"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }
}
