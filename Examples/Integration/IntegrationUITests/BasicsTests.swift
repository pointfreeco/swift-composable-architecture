import TestCases
import XCTest

@MainActor
final class BasicsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Basics"].tap()
    self.clearLogs()
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    BasicsView.body
    """)
    self.app.buttons["Decrement"].tap()
    self.assertLogs("""
    StoreOf<Integration.BasicsView.Feature>.scope
    BasicsView.body
    """)
  }
}
