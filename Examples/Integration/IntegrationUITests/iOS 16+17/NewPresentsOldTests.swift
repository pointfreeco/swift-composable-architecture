import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS16_17_NewPresentsOldTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16 + 17"].tap()
    self.app.buttons["New presents old"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.init
      """
    }
  }

  func testPresentChild_NotObservingChildCount() {
    self.app.buttons["Present child"].tap()
    self.assertLogs {
      """
      BasicsView.body
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
  }

  func testDismissChild_NotObservingChildCount() {
    self.app.buttons["Present child"].tap()
    self.clearLogs()
    self.app.buttons["Dismiss"].tap()
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      BasicsView.body
      NewPresentsOldTestCase.body
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
  }

  func testObserveChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    XCTAssertEqual(self.app.staticTexts["Child count: N/A"].exists, true)
    self.assertLogs {
      """
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.init
      """
    }
  }

  func testPresentChild_ObservingChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    self.clearLogs()
    self.app.buttons["Present child"].tap()
    XCTAssertEqual(self.app.staticTexts["0"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Child count: 0"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
  }

  func testIncrementChild_ObservingChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    self.app.buttons["Present child"].tap()
    self.clearLogs()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 0).tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Child count: 1"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      BasicsView.body
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
  }

  func testDismissChild_ObservingChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    self.app.buttons["Present child"].tap()
    self.clearLogs()
    self.app.buttons["Dismiss"].tap()
    self.assertLogs {
      """
      BasicsView.body
      BasicsView.body
      BasicsView.body
      NewPresentsOldTestCase.body
      NewPresentsOldTestCase.body
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      PresentationStoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      StoreOf<BasicsView.Feature?>.init
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewPresentationStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      ViewStoreOf<BasicsView.Feature?>.init
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      WithViewStoreOf<BasicsView.Feature?>.body
      """
    }
  }

  func testDeinit() {
    self.app.buttons["Toggle observe child count"].tap()
    self.app.buttons["Present child"].tap()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 0).tap()
    self.app.buttons["Dismiss"].tap()
    self.clearLogs()
    self.app.buttons["iOS 16 + 17"].tap()
    self.assertLogs {
      """
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      PresentationStoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      StoreOf<BasicsView.Feature?>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewPresentationStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature?>.deinit
      """
    }
  }
}
