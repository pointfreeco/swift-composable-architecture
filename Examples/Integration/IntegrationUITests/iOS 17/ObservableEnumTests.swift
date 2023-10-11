import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservableEnumTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Observable Enum"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["FEATURE 1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableEnumView.body
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableEnumView.Feature.Destination>.init
      """
    }
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      StoreOf<ObservableEnumView.Feature>.scope
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
      ObservableEnumView.body
      StoreOf<ObservableEnumView.Feature.Destination>.scope
      StoreOf<ObservableEnumView.Feature>.scope
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
      ObservableBasicsView.body
      ObservableEnumView.body
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableEnumView.Feature.Destination>.init
      StoreOf<ObservableEnumView.Feature.Destination>.scope
      StoreOf<ObservableEnumView.Feature>.scope
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
      ObservableEnumView.body
      StoreOf<ObservableEnumView.Feature.Destination>.scope
      StoreOf<ObservableEnumView.Feature>.scope
      StoreOf<ObservableEnumView.Feature>.scope
      """
    }
  }
}
