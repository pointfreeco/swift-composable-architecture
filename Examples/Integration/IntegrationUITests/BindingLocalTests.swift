import TestCases
import XCTest

@MainActor
final class BindingLocalTests: BaseIntegrationTests {
  func testNoBindingWarning() {
    app.collectionViews.buttons[TestCase.bindingLocal.rawValue].tap()

    app.buttons["Child"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }

  func testOnDisappearWarning() {
    self.expectRuntimeWarnings = true

    app.collectionViews.buttons[TestCase.bindingLocal.rawValue].tap()

    app.buttons["Child"].tap()

    app.buttons["Send onDisappear"].tap()

    app.textFields["Text"].tap()

    app.buttons["Dismiss"].tap()
  }
}
