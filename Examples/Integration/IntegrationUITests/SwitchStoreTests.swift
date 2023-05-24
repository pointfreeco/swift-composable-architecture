import Integration
import TestCases
import XCTest

@MainActor
final class SwitchStoreTests: BaseIntegrationTests {
  func testExample() async throws {
    self.expectRuntimeWarnings()

    app.collectionViews.buttons[TestCase.switchStore.rawValue].tap()

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
