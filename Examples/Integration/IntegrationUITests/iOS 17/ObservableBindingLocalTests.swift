import InlineSnapshotTesting
import TestCases
import XCTest

final class iOS17_ObservableBindingLocalTests: BaseIntegrationTests {
  @MainActor
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Binding local"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  @MainActor
  func testNoBindingWarning_FullScreenCover() {
    self.app.buttons["Full-screen-cover"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testOnDisappearWarning_FullScreenCover() {
    self.expectRuntimeWarnings()

    self.app.buttons["Full-screen-cover"].tap()

    self.app.buttons["Send onDisappear"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testNoBindingWarning_NavigationDestination() {
    self.app.buttons["Navigation destination"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testOnDisappearWarning_NavigationDestination() {
    self.expectRuntimeWarnings()

    self.app.buttons["Navigation destination"].tap()

    self.app.buttons["Send onDisappear"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testNoBindingWarning_Path() {
    self.app.buttons["Path"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testOnDisappearWarning_Path() {
    self.expectRuntimeWarnings()

    self.app.buttons["Path"].tap()

    self.app.buttons["Send onDisappear"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testNoBindingWarning_Popover() {
    self.app.buttons["Popover"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testOnDisappearWarning_Popover() {
    self.expectRuntimeWarnings()

    self.app.buttons["Popover"].tap()

    self.app.buttons["Send onDisappear"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testNoBindingWarning_Sheet() {
    self.app.buttons["Sheet"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }

  @MainActor
  func testOnDisappearWarning_Sheet() {
    self.expectRuntimeWarnings()

    self.app.buttons["Sheet"].tap()

    self.app.buttons["Send onDisappear"].tap()

    self.app.textFields["Text"].tap()

    self.app.buttons["Dismiss"].tap()
  }
}
