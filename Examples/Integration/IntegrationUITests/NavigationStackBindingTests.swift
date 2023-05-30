import TestCases
import XCTest

@MainActor
final class NavigationStackBindingTests: BaseIntegrationTests {
  func testExample() async throws {
    app.collectionViews.buttons[TestCase.navigationStackBinding.rawValue].tap()
    app.buttons["Go to child"].tap()
    app.buttons["Back"].tap()
    XCTAssertTrue(app.buttons["Go to child"].exists)
  }
}
