import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS16_IdentifiedListTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Identified list"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Add"].tap()
    self.assertLogs {
      """
      BasicsView.body
      IdentifiedListView.body
      IdentifiedListView.body.ForEachStore
      IdentifiedListView.body.ForEachStore
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<IdentifiedListView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
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
      BasicsView.body
      IdentifiedListView.body
      IdentifiedListView.body.ForEachStore
      IdentifiedListView.body.ForEachStore
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.scope
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, Action>
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
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
      BasicsView.body
      IdentifiedStoreOf<BasicsView.Feature>.scope
      IdentifiedStoreOf<BasicsView.Feature>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      Store<UUID, BasicsView.Feature.Action>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<BasicsView.Feature>.scope
      StoreOf<IdentifiedListView.Feature>.scope
      """
    }
  }
}
