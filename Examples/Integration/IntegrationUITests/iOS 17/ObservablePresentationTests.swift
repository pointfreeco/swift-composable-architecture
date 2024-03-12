import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservablePresentationTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Presentation"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testOptional() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      """
    }
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      """
    }
  }

  @MainActor
  func testOptional_ObserveChildCount() {
    self.app.buttons["Present sheet"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      StoreOf<ObservableBasicsView.Feature>.init
      """
    }
    self.app.buttons["Observe child count"].tap()
    self.assertLogs {
      """
      ObservablePresentationView.body
      """
    }
    self.app.buttons["Increment"].tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      """
    }
    XCTAssertEqual(self.app.staticTexts["Count: 1"].exists, true)
    self.app.buttons["Dismiss"].firstMatch.tap()
    self.assertLogs {
      """
      ObservableBasicsView.body
      ObservablePresentationView.body
      """
    }
  }
}
