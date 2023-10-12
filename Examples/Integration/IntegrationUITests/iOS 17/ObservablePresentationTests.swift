import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class ObservablePresentationTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Observable Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testOptional() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.deinit
      """
    }
  }

  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.deinit
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservableBasicsView.Feature>.init
      StoreOf<ObservablePresentationView.Feature>.scope
      StoreOf<ObservablePresentationView.Feature>.scope
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.deinit
      """
    }
  }
}
