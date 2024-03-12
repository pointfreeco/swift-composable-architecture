import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS16_IdentifiedListTests: BaseIntegrationTests {
  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    self.app.buttons["iOS 16"].tap()
    self.app.buttons["Identified list"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testBasics() {
    self.app.buttons["Add"].tap()
    self.assertLogs {
      """
      BasicsView.body
      IdentifiedListView.body
      IdentifiedListView.body.ForEachStore
      IdentifiedListView.body.ForEachStore
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.init
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      StoreOf<BasicsView.Feature>.init
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.deinit
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      ViewStoreOf<BasicsView.Feature>.init
      WithViewIdentifiedStoreOf<BasicsView.Feature>.body
      WithViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }

  @MainActor
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
      IdentifiedStoreOf<BasicsView.Feature>.deinit
      IdentifiedStoreOf<BasicsView.Feature>.init
      IdentifiedStoreOf<BasicsView.Feature>.init
      Store<UUID, Action>
      Store<UUID, Action>
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.deinit
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      Store<UUID, BasicsView.Feature.Action>.init
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.deinit
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewIdentifiedStoreOf<BasicsView.Feature>.init
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.deinit
      ViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.deinit
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStore<UUID, BasicsView.Feature.Action>.init
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewIdentifiedStoreOf<BasicsView.Feature>.body
      WithViewStore<IdentifiedListView.ViewState, IdentifiedListView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStore<UUID, BasicsView.Feature.Action>.body
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }

  @MainActor
  func testAddTwoIncrementSecond() {
    self.app.buttons["Add"].tap()
    self.app.buttons["Add"].tap()
    self.clearLogs()
    self.app.buttons.matching(identifier: "Increment").element(boundBy: 1).tap()
    XCTAssertEqual(self.app.staticTexts["Count: 0"].exists, true)
    self.assertLogs {
      """
      BasicsView.body
      ViewStoreOf<BasicsView.Feature>.deinit
      ViewStoreOf<BasicsView.Feature>.init
      WithViewStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
