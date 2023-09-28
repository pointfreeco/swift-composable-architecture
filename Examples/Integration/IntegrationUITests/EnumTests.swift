import TestCases
import XCTest

@MainActor
final class EnumTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Enum"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.assertLogs("""
    EnumView.body
    StoreOf<Integration.EnumView.Feature.Destination>.init
    StoreOf<Integration.BasicsView.Feature>.init
    BasicsView.body
    """)
    self.app.buttons["Increment"].tap()
    self.assertLogs("""
    StoreOf<Integration.EnumView.Feature>.scope
    BasicsView.body
    """)
    self.app.buttons["Increment"].tap()
    self.assertLogs("""
    StoreOf<Integration.EnumView.Feature>.scope
    BasicsView.body
    """)
  }

  func testToggle1On_Toggle1Off() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 1 off"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, false)
    self.assertLogs("""
    StoreOf<Integration.EnumView.Feature.Destination>.scope
    StoreOf<Integration.EnumView.Feature>.scope
    EnumView.body
    StoreOf<Integration.BasicsView.Feature>.deinit
    StoreOf<Integration.EnumView.Feature.Destination>.deinit
    """)
  }

  func testToggle1On_Toggle2On() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Toggle feature 2 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 2"].exists, true)
    self.assertLogs("""
    StoreOf<Integration.EnumView.Feature.Destination>.scope
    StoreOf<Integration.EnumView.Feature>.scope
    EnumView.body
    StoreOf<Integration.EnumView.Feature.Destination>.init
    StoreOf<Integration.BasicsView.Feature>.init
    BasicsView.body
    StoreOf<Integration.BasicsView.Feature>.deinit
    StoreOf<Integration.EnumView.Feature.Destination>.deinit
    """)
  }

  func testDismiss() {
    self.app.buttons["Toggle feature 1 on"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, true)
    self.clearLogs()
    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["Feature 1"].exists, false)
    self.assertLogs("""
    StoreOf<Integration.EnumView.Feature>.scope
    StoreOf<Integration.EnumView.Feature.Destination>.scope
    StoreOf<Integration.EnumView.Feature>.scope
    EnumView.body
    StoreOf<Integration.BasicsView.Feature>.deinit
    StoreOf<Integration.EnumView.Feature.Destination>.deinit
    """)
  }
}
