import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class PresentationTests: BaseIntegrationTests {
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
    //SnapshotTesting.isRecording = true
  }

  func testOptional() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)

    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      """
    }
  }

  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationView.body
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationView.body
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.deinit
      ViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      WithViewStore<PresentationView.ViewState, PresentationView.Feature.Action>.body
      """
    }
  }
}
