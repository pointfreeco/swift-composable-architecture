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
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.deinit
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.init
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, false)
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
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
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.init
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableOptionalView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.deinit
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.init
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableOptionalView.Feature>.scope
      StoreOf<ObservableOptionalView.Feature>.scope
      """
    }
  }
}
