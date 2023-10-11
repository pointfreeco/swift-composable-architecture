import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class PresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
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
    self.assertLogs {
      """
      BasicsView.body
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
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
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
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
    self.assertLogs {
      """
      BasicsView.body
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
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationView.body
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      StoreOf<PresentationView.Feature>.scope
      """
    }
  }
}
