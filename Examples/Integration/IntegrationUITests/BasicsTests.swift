import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class BasicsTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["Basics"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testBasics() {
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithStoreOf<BasicsView.Feature>.body
      """
    }
    self.app.buttons["Decrement"].tap()
    self.assertLogs {
      """
      BasicsView.body
      StoreOf<BasicsView.Feature>.scope
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.deinit
      ViewStore<BasicsView.Feature.State, BasicsView.Feature.Action>.init
      WithStoreOf<BasicsView.Feature>.body
      """
    }
  }
}
