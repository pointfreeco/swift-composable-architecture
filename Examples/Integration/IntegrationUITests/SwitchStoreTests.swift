import XCTest

@MainActor
final class SwitchStoreTests: XCTestCase {
  override func setUpWithError() throws {
    self.continueAfterFailure = false
  }

  func testExample() async throws {
    let app = XCUIApplication()
    app.launch()

    app.collectionViews.buttons["SwitchStoreTestCase"].tap()

    XCTAssertFalse(app.staticTexts["Warning"].exists)

    app.buttons["Swap"].tap()

    // TODO: Figure out how to assert this
    //XCTAssertTrue(app.staticTexts["Warning"].exists)
  }
}
