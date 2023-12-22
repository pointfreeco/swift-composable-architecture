import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS16_OptionalTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
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
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.deinit
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
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

  func testParentObserveChild() {
    self.app.buttons["Toggle"].tap()
    self.app.buttons["Increment"].tap()
    self.clearLogs()
    self.app.buttons["Observe count"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.assertLogs {
      """
      OptionalView.body
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
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.deinit
      ViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStore<OptionalView.ViewState, OptionalView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
