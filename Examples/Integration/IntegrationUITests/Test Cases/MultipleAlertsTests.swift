import TestCases
import XCTest

final class MultipleAlertsTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
    try super.setUpWithError()
    self.app.buttons["Test cases"].tap()
    app.collectionViews.buttons[TestCase.Cases.multipleAlerts.rawValue].tap()
  }

  @MainActor
  func testMultipleAlerts() {
    app.buttons["Show alert"].tap()

    app.buttons["Another!"].tap()

    app.buttons["I'm done"].tap()
  }
}
