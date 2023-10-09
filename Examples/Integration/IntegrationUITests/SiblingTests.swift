import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class SiblingsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Siblings"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      """
    }
  }

  func testResetAll() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset all"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      """
    }
  }

  func testResetSelf() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset self"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      """
    }
  }

  func testResetSwap() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Swap"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      StoreOf<SiblingFeaturesView.Feature>.scope
      """
    }
  }
}
