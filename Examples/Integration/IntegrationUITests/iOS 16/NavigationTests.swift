import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS16_NavigationTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Navigation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
    self.app.buttons["Increment"].tap()
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
  func testDeepStack() {
    self.app.buttons["Push feature"].tap()
    self.app.buttons["Push feature"].tap()
    self.app.buttons["Push feature"].tap()
    self.app.buttons["Push feature"].tap()
    self.app.buttons["Push feature"].tap()
    self.clearLogs()
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
