import TestCases
import XCTest

@MainActor
final class PresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
  }
}
