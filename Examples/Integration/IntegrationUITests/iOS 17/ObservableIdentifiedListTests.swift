import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS17_ObservableIdentifiedListTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Identified list"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Add"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableIdentifiedListView.body
      ObservableIdentifiedListView.body.ForEach
      ObservableIdentifiedListView.body.ForEach
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
  }

  func testAddTwoIncrementFirst() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.buttons["Increment"].firstMatch.tap()
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableIdentifiedListView.body
      ObservableIdentifiedListView.body.ForEach
      ObservableIdentifiedListView.body.ForEach
      """
    }
  }

  func testAddTwoIncrementSecond() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 1).tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
  }
}
