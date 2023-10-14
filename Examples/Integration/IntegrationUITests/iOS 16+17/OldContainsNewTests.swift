import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class OldContainsNewTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16 + 17"].tap()
    self.app.buttons["Old containing new"].tap()
    self.clearLogs()
    SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      OldContainsNewTestCase.body
      StoreOf<OldContainsNewTestCase.Feature>.scope
      """
    }
  }

  func testObserveChildCount() {
    self.app.buttons["Toggle observe child count"].tap()
    XCTAssertEqual(self.app.staticTexts["Child count: N/A"].exists, true)
    self.assertLogs {
      """
      OldContainsNewTestCase.body
      StoreOf<OldContainsNewTestCase.Feature>.scope
      """
    }

    self.app.buttons["Present child"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      OldContainsNewTestCase.body
      OldContainsNewTestCase.body
      PresentationStoreOf<ObservableBasicsView.Feature>.deinit
      PresentationStoreOf<ObservableBasicsView.Feature>.deinit
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature?>.deinit
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<OldContainsNewTestCase.Feature>.scope
      """
    }

    self.app.buttons.matching(identifier: "Increment").element(boundBy: 0).tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Child count: 1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      OldContainsNewTestCase.body
      OldContainsNewTestCase.body
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature?>.deinit
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      """
    }

    self.app.buttons["Dismiss"].tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, false)
    XCTAssertEqual(self.app.staticTexts["Child count: N/A"].exists, true)
    self.assertLogs {
      """
      OldContainsNewTestCase.body
      OldContainsNewTestCase.body
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      PresentationStoreOf<ObservableBasicsView.Feature>.init
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      PresentationStoreOf<ObservableBasicsView.Feature>.scope
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature?>.deinit
      StoreOf<ObservableBasicsView.Feature?>.deinit
      StoreOf<ObservableBasicsView.Feature?>.deinit
      StoreOf<ObservableBasicsView.Feature?>.init
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<ObservableBasicsView.Feature?>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      StoreOf<OldContainsNewTestCase.Feature>.scope
      """
    }
  }
}
