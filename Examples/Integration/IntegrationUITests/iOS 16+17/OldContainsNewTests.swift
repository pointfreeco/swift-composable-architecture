import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS16_17_OldContainsNewTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16 + 17"].tap()
    self.app.buttons["Old containing new"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testIncrementDecrement() {
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 0).tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    self.assertLogs {
      """
      OldContainsNewTestCase.body
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      WithViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.body
      """
    }

    self.app.buttons.matching(identifier: "Decrement").element(boundBy: 0).tap()
    XCTAssertEqual(self.app.staticTexts["-1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      OldContainsNewTestCase.body
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      WithViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.body
      """
    }
  }

  @MainActor
  func testObserveChildCount() {
    self.app.buttons["Toggle observing child count"].tap()
    XCTAssertEqual(self.app.staticTexts["Child count: 0"].exists, true)
    self.assertLogs {
      """
      OldContainsNewTestCase.body
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      WithViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.body
      """
    }
  }

  @MainActor
  func testIncrementChild_ObservingChildCount() {
    self.app.buttons["Toggle observing child count"].tap()
    self.clearLogs()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 1).tap()
    XCTAssertEqual(self.app.staticTexts["1"].exists, true)
    XCTAssertEqual(self.app.staticTexts["Child count: 1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      OldContainsNewTestCase.body
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.init
      WithViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.body
      """
    }
  }

  @MainActor
  func testDeinit() {
    self.app.buttons["Toggle observing child count"].tap()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 1).tap()
    self.clearLogs()
    self.app.buttons["iOS 16 + 17"].tap()
    self.assertLogs {
      """
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      Store<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      ViewStore<OldContainsNewTestCase.ViewState, OldContainsNewTestCase.Feature.Action>.deinit
      """
    }
  }
}
