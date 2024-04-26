import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS16_PresentationTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testOptional() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)

    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
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
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      """
    }
  }

  @MainActor
  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      PresentationView.body
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationView.body
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      PresentationView.body
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      """
    }
  }
}
