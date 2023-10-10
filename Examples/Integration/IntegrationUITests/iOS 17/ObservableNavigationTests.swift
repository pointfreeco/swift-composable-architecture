import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservableNavigationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Observable Navigation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Push feature"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.init
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
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
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      Store<StackState<ObservableBasicsView.Feature.State>, StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableNavigationTestCaseView.Feature>.scope
      """
    }
  }
}
