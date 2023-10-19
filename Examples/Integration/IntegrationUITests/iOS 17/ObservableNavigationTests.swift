import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS17_ObservableNavigationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Observable Navigation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      StackStoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableNavigationTestCaseView.Feature>.scope
      StoreOf<ObservableNavigationTestCaseView.Feature>.scope
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
      ObservableBasicsView.body
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StackStoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableNavigationTestCaseView.Feature>.scope
      StoreOf<ObservableNavigationTestCaseView.Feature>.scope
      """
    }
  }
}
