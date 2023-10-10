import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservableOptionalTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Observable Optional"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Toggle"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableOptionalView.Feature>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
  }

  func testParentObserveChild() {
    self.app.buttons["Toggle"].tap()
    self.app.buttons["Increment"].tap()
    self.clearLogs()
    self.app.buttons["Observe count"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.assertLogs {
      """
      ObservableOptionalView.body
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
  }
}
