import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class PresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testOptional() {
    self.app.buttons["Present sheet"].tap()
    self.app.buttons["Increment"].tap()
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
  }

  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.app.buttons["Observe child count"].tap()
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      PresentationView.body
      PresentationView.body
      PresentationView.body
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<BasicsView.Feature.State?, BasicsView.Feature.Action>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      Store<PresentationState<BasicsView.Feature.State>, PresentationAction<BasicsView.Feature.Action>>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
  }
}
