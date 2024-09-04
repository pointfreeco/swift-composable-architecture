import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservableSiblingsTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Siblings"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testBasics() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }

  @MainActor
  func testResetAll() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset all"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableSiblingFeaturesView.body
      """
    }
  }

  @MainActor
  func testResetSelf() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset self"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      """
    }
  }

  @MainActor
  func testResetSwap() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Swap"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableSiblingFeaturesView.body
      """
    }
  }
}
