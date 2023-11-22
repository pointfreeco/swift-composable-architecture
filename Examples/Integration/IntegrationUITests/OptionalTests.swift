import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class OptionalTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Optional"].tap()
    self.clearLogs()
    //SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Toggle"].tap()
    self.assertLogs {
      """
      BasicsView.body
      OptionalView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<OptionalView.Feature>.scope
      StoreOf<OptionalView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.deinit
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<OptionalView.Feature>.scope
      StoreOf<OptionalView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
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
      OptionalView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<OptionalView.Feature>.scope
      StoreOf<OptionalView.Feature>.scope
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.deinit
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.init
      WithViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      OptionalView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<OptionalView.Feature>.scope
      StoreOf<OptionalView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.deinit
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.init
      WithViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
