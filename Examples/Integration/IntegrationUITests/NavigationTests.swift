import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class NavigationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Navigation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StackStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StackStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<NavigationTestCaseView.Feature>.scope
      """
    }
  }

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
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StackStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<NavigationTestCaseView.Feature>.scope
      """
    }
  }
}
