import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class EnumTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Enum"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      EnumView.body
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<EnumView.Feature.Destination>.init
      StoreOf<EnumView.Feature.Destination>.init
      StoreOf<EnumView.Feature.Destination?>.init
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStore<EnumView.Feature.Destination.State, EnumView.Feature.Destination.Action>.deinit
      ViewStore<EnumView.Feature.Destination.State, EnumView.Feature.Destination.Action>.init
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.deinit
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.init
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.deinit
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<EnumView.Feature.Destination>.init
      WithStore<EnumView.ViewState, EnumView.Feature.Action>.body
      WithStoreOf<BasicsView.Feature>.body
      WithStoreOf<BasicsView.Feature?>.body
      WithStoreOf<EnumView.Feature.Destination>.body
      WithStoreOf<EnumView.Feature.Destination?>.body
      """
    }
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithStoreOf<BasicsView.Feature>.body
      """
    }
  }

  func testToggle1On_Toggle1Off() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 1 off"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, false)
    self.assertLogs {
      """
      EnumView.body
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.deinit
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.init
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.deinit
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.init
      WithStore<EnumView.ViewState, EnumView.Feature.Action>.body
      WithStoreOf<EnumView.Feature.Destination?>.body
      """
    }
  }

  func testToggle1On_Toggle2On() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 2 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 2"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      EnumView.body
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStore<BasicsView.Feature.State?, BasicsView.Feature.Action>.init
      ViewStore<EnumView.Feature.Destination.State, EnumView.Feature.Destination.Action>.deinit
      ViewStore<EnumView.Feature.Destination.State, EnumView.Feature.Destination.Action>.init
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.deinit
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithStore<EnumView.ViewState, EnumView.Feature.Action>.body
      WithStoreOf<BasicsView.Feature>.body
      WithStoreOf<BasicsView.Feature?>.body
      WithStoreOf<BasicsView.Feature?>.body
      WithStoreOf<EnumView.Feature.Destination>.body
      """
    }
  }

  func testDismiss() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, false)
    self.assertLogs {
      """
      EnumView.body
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      PresentationStoreOf<EnumView.Feature.Destination>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature.Destination?>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      StoreOf<EnumView.Feature>.scope
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.deinit
      ViewStore<EnumView.Feature.Destination.State?, EnumView.Feature.Destination.Action>.init
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.deinit
      ViewStore<EnumView.ViewState, EnumView.Feature.Action>.init
      WithStore<EnumView.ViewState, EnumView.Feature.Action>.body
      WithStoreOf<EnumView.Feature.Destination?>.body
      """
    }
  }
}
