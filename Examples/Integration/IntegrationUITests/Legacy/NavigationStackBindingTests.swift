import TestCases
import XCTest

@MainActor
final class NavigationStackBindingTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Legacy"].tap()
  }

  func testExample() async throws {
    app.collectionViews.buttons[TestCase.navigationStackBinding.rawValue].tap()
    app.buttons["Go to child"].tap()
    app.buttons["Back"].tap()
    XCTAssertTrue(app.buttons["Go to child"].exists)
  }
}
