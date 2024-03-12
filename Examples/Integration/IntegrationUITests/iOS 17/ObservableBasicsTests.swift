import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservableBasicsTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Basics"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
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

  @MainActor
  func testReset() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()

    self.app.buttons["Reset"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }

  @MainActor
  func testCopyIncrementDiscard() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()

    self.app.buttons["Copy, increment, discard"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }

  @MainActor
  func testCopyIncrementSet() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()

    self.app.buttons["Copy, increment, set"].tap()
    XCTAssertEqual(self.app.staticTexts["2"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }

    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["3"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }
}
