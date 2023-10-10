import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservableBasicsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Observable Basics"].tap()
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
      ObservableBasicsView.body
      """
    }
    self.app.buttons["Decrement"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }
}
