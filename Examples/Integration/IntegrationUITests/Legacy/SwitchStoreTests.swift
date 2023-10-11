import Integration
import TestCases
import XCTest

@MainActor
final class SwitchStoreTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Legacy"].tap()
    app.collectionViews.buttons[TestCase.switchStore.rawValue].tap()
  }

  func testExample() async throws {
    self.expectRuntimeWarnings()

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
