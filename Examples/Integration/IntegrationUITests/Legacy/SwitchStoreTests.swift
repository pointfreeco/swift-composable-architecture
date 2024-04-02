import Integration
import TestCases
import XCTest

final class SwitchStoreTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    app.buttons["Legacy"].tap()
    app.collectionViews.buttons[TestCase.switchStore.rawValue].tap()
  }

  @MainActor
  func testExample() async throws {
    expectRuntimeWarnings()

    XCTAssertFalse(
      app.staticTexts
        .containing(NSPredicate(format: #"label CONTAINS[c] "Warning: ""#))
        .element
        .exists
    )

    app.buttons["Swap"].tap()

    XCTAssertTrue(
      app.staticTexts
        .containing(NSPredicate(format: #"label CONTAINS[c] "Warning: ""#))
        .element
        .exists
    )
  }
}
