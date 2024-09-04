import InlineSnapshotTesting
import TestCases
import XCTest

@MainActor
final class iOS17_ObservableSharedStateTests: BaseIntegrationTests {
  override func setUp() {
    super.setUp()
    self.app.buttons["iOS 17"].tap()
    self.app.buttons["Shared state"].tap()
    self.app.buttons["Reset"].tap()
    self.clearLogs()
    // SnapshotTesting.isRecording = true
  }

  func testUserDefaults() {
    self.app.buttons["isAppStorageOn1"].tap()
    XCTAssertEqual(self.app.staticTexts["App Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["App Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["isAppStorageOn2"].tap()
    XCTAssertEqual(self.app.staticTexts["App Storage #1 ❌"].exists, true)
    XCTAssertEqual(self.app.staticTexts["App Storage #2 ❌"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["Write directly to user defaults"].tap()
    XCTAssertEqual(self.app.staticTexts["App Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["App Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["Delete user default"].tap()
    XCTAssertEqual(self.app.staticTexts["App Storage #1 ❌"].exists, true)
    XCTAssertEqual(self.app.staticTexts["App Storage #2 ❌"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      ObservableSharedStateView.body
      """
    }
  }

  func testFileStorage() {
    self.app.buttons["isFileStorageOn1"].tap()
    XCTAssertEqual(self.app.staticTexts["File Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["File Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["isFileStorageOn2"].tap()
    XCTAssertEqual(self.app.staticTexts["File Storage #1 ❌"].exists, true)
    XCTAssertEqual(self.app.staticTexts["File Storage #2 ❌"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["Write directly to file system"].tap()
    XCTAssertEqual(self.app.staticTexts["File Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["File Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["Delete file"].tap()
    XCTAssertEqual(self.app.staticTexts["File Storage #1 ❌"].exists, true)
    XCTAssertEqual(self.app.staticTexts["File Storage #2 ❌"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }
  }

  func testInMemory() {
    self.app.buttons["isInMemoryOn1"].tap()
    XCTAssertEqual(self.app.staticTexts["In-memory Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["In-memory Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }

    self.app.buttons["isInMemoryOn2"].tap()
    XCTAssertEqual(self.app.staticTexts["In-memory Storage #1 ❌"].exists, true)
    XCTAssertEqual(self.app.staticTexts["In-memory Storage #2 ❌"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }
  }

  func testFileStorage_DeleteFileThenMutate() {
    self.app.buttons["Delete file"].tap()
    self.clearLogs()

    self.app.buttons["Write directly to file system"].tap()
    XCTAssertEqual(self.app.staticTexts["File Storage #1 ✅"].exists, true)
    XCTAssertEqual(self.app.staticTexts["File Storage #2 ✅"].exists, true)
    self.assertLogs {
      """
      ObservableSharedStateView.body
      """
    }
  }
}
