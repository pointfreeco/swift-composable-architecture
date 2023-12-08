import TestCases
import XCTest

@MainActor
final class IfLetStoreTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["Legacy"].tap()
    self.app.buttons[TestCase.ifLetStore.rawValue].tap()
  }

  func testBasics() async throws {
    XCTAssertEqual(
      self.app.buttons["Show"].waitForExistence(timeout: 1),
      true
    )
    self.app.buttons["Show"].tap()
    XCTAssertEqual(
      self.app.buttons["Dismiss"].waitForExistence(timeout: 1),
      true
    )
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(
      self.app.buttons["Show"].waitForExistence(timeout: 1),
      true
    )
  }
}
