import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class SiblingsTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
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
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
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
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
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
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
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
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
