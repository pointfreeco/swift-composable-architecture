import TestCases
import XCTest

@MainActor
final class SiblingsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Siblings"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    StoreOf<Integration.BasicsView.Feature>.scope
    BasicsView.body
    """)
  }

  func testResetAll() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset all"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    BasicsView.body
    BasicsView.body
    """)
  }

  func testResetSelf() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Reset self"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    BasicsView.body
    BasicsView.body
    """)
  }

  func testResetSwap() {
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.clearLogs()
    self.app.buttons["Swap"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    StoreOf<Integration.BasicsView.Feature>.scope
    StoreOf<Integration.SiblingFeaturesView.Feature>.scope
    BasicsView.body
    BasicsView.body
    """)
  }
}
