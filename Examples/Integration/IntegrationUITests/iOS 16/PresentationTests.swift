import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS16_PresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testOptional() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs ()
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs()
  }

  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      PresentationView.body
      StoreOf<PresentationView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs()
  }
}
