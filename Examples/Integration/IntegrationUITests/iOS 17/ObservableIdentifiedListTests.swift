import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS17_ObservableIdentifiedListTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Observable Identified list"].tap()
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
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.deinit
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.init
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableIdentifiedListView.Feature>.scope
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
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.init
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
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
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, IdentifiedArrayAction<ObservableBasicsView.Feature>>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      """
    }
  }
}
