import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservableNavigationTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Navigation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
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
      ObservableBasicsView.body
      """
    }
  }
}
