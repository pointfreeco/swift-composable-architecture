import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservableEnumScopePresentationTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Enum scope presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testReplaceFullScreenCoverWithNavigationDestination() {
    self.app.buttons["Present full-screen cover"].tap()
    self.app.buttons["Push feature"].tap()
    XCTAssertEqual(self.app.buttons["Push feature"].waitForNonExistence(timeout: 1), true)
    XCTAssertEqual(
      self.app.buttons["Present full-screen cover"].waitForExistence(timeout: 1),
      false
    )
    XCTAssertEqual(self.app.navigationBars["Pushed feature"].exists, true)
  }
}
