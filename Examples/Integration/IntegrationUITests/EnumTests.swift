import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class EnumTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
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
      """
    }
  }
}
