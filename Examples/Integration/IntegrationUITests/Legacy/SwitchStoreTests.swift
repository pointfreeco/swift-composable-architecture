import Integration
import TestCases
import XCTest

@MainActor
final class SwitchStoreTests: BaseIntegrationTests {
  override func setUp() async throws {
    try await super.setUp()
    self.app.buttons["Legacy"].tap()
  }

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
