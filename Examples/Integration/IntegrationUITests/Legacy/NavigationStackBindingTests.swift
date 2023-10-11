import TestCases
import XCTest

@MainActor
final class NavigationStackBindingTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Legacy"].tap()
    app.collectionViews.buttons[TestCase.navigationStackBinding.rawValue].tap()
  }

  func testExample() async throws {
    app.buttons["Go to child"].tap()
    app.buttons["Root"].tap()
    XCTAssertTrue(app.buttons["Go to child"].exists)
  }
}
