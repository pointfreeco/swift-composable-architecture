import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS16_SiblingsTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
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
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
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
      BasicsView.body
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
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
      BasicsView.body
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
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
      BasicsView.body
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
