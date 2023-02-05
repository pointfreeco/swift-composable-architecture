import XCTest

@MainActor
final class NavigationStackBindingTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()
    app.collectionViews.buttons["NavigationStackBindingTestCase"].tap()
    app.buttons["Go to child"].tap()
    app.buttons["Back"].tap()
    XCTAssertTrue(app.buttons["Go to child"].exists)
  }
}
