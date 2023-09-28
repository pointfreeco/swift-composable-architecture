import TestCases
import XCTest

@MainActor
final class OptionalTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Optional"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Toggle"].tap()
    self.assertLogs("""
    OptionalView.body
    StoreOf<Integration.BasicsView.Feature>.init
    BasicsView.body
    """)
    self.app.buttons["Increment"].tap()
    self.assertLogs("""
    BasicsView.body
    """)
  }

  func testParentObserveChild() {
    self.app.buttons["Toggle"].tap()
    self.app.buttons["Increment"].tap()
    self.clearLogs()
    self.app.buttons["Observe count"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.assertLogs("""
    StoreOf<Integration.OptionalView.Feature>.scope
    OptionalView.body
    StoreOf<Integration.BasicsView.Feature>.init
    BasicsView.body
    """)
  }
}
