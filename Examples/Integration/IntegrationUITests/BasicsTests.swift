import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class BasicsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Basics"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      """
    }
    self.app.buttons["Decrement"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      """
    }
  }
}
