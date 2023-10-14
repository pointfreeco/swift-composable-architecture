import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class NewContainsOldTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16 + 17"].tap()
    self.app.buttons["New containing old"].tap()
    self.clearLogs()
    SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      NewContainsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      """
    }
  }

  func testObserveChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    XCTAssertEqual(self.app.staticTexts["Child count: N/A"].exists, true)
    self.assertLogs {
      """
      NewContainsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      Store<Int?, NewContainsOldTestCase.Feature.Action>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      """
    }

    self.app.buttons["Present child"].tap()
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
      StoreOf<NewContainsOldTestCase.Feature>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      """
    }

    self.app.buttons.matching(identifier: "Increment").element(boundBy: 0).tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Child count: 1"].exists, true)
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
      StoreOf<NewContainsOldTestCase.Feature>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      """
    }

    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    XCTAssertEqual(self.app.staticTexts["Child count: N/A"].exists, true)
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      PresentationStoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<BasicsView.Feature?>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      StoreOf<NewContainsOldTestCase.Feature>.scope
      """
    }
  }
}
