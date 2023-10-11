import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservableIdentifiedListTests: BaseIntegrationTests {
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
      ObservableIdentifiedListView.body.ForEachStore
      ObservableIdentifiedListView.body.ForEachStore
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.deinit
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.deinit
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.init
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.init
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<UUID, Action>
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableIdentifiedListView.Feature>.scope
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
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservableIdentifiedListView.body
      ObservableIdentifiedListView.body.ForEachStore
      ObservableIdentifiedListView.body.ForEachStore
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.deinit
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.init
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.init
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<UUID, Action>
      Store<UUID, Action>
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.deinit
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.init
      Store<UUID, ObservableBasicsView.Feature.Action>.scope
      Store<UUID, ObservableBasicsView.Feature.Action>.scope
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      """
    }
  }

  func testAddTwoIncrementSecond() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.cells.element(boundBy: 2).buttons["Increment"].tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.assertLogs {
      """
      ObservableBasicsView.body
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<IdentifiedArray<UUID, ObservableBasicsView.Feature.State>, (UUID, ObservableBasicsView.Feature.Action)>.scope
      Store<UUID, ObservableBasicsView.Feature.Action>.scope
      Store<UUID, ObservableBasicsView.Feature.Action>.scope
      StoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableBasicsView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      StoreOf<ObservableIdentifiedListView.Feature>.scope
      """
    }
  }
}
