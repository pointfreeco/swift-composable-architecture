import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class BasicsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Basics"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, false)
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      """
    }
    self.app.buttons["Decrement"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      """
    }
  }
}
