import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservablePresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Observable Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testOptional() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
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
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
  }

  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.init
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      ObservablePresentationView.body
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      ObservablePresentationView.body
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.deinit
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
      Store<ObservableBasicsView.Feature.State?, ObservableBasicsView.Feature.Action>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      Store<PresentationState<ObservableBasicsView.Feature.State>, PresentationAction<ObservableBasicsView.Feature.Action>>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
  }
}
