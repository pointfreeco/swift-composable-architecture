import Accessibility
import CustomDump
@preconcurrency import InlineSnapshotTesting
import XCTest

class BaseIntegrationTests: XCTestCase {
  @MainActor
  var app: XCUIApplication!
  var logs: XCUIElement!
  private var _expectRuntimeWarnings: (file: StaticString, line: UInt)?

  func expectRuntimeWarnings(file: StaticString = #file, line: UInt = #line) {
    self._expectRuntimeWarnings = (file, line)
  }

  @MainActor
  override func setUp() async throws {
    // SnapshotTesting.isRecording = true
    // self.continueAfterFailure = false
    self.app = XCUIApplication()
    self.app.launchEnvironment["UI_TEST"] = "true"
    self.app.launch()
    self.app.activate()
    self.logs = self.app.staticTexts["composable-architecture.debug.logs"]
  }

  @MainActor
  override func tearDown() {
    super.tearDown()
    if let (file, line) = self._expectRuntimeWarnings {
      XCTAssert(
        self.app.staticTexts["Runtime warning"].waitForExistence(timeout: 1),
        "Expected runtime warning(s)",
        file: file,
        line: line
      )
    } else {
      XCTAssertFalse(
        self.app.staticTexts["Runtime warning"].exists,
        "\(self.name) emitted an unexpected runtime warning"
      )
    }
    SnapshotTesting.isRecording = false
  }

  @MainActor
  func clearLogs() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts
      let open = alert.buttons["Open"]
      if alert.firstMatch.waitForExistence(timeout: 0.3),
        open.waitForExistence(timeout: 0.3)
      {
        alert.buttons["Open"].tap()
      }
    }
    XCUIDevice.shared.system.open(URL(string: "integration:///clear-logs")!)
  }

  @MainActor
  func assertLogs(
    _ logConfiguration: LogConfiguration = .unordered,
    matches expectedLogs: (() -> String)? = nil,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
  ) {
    defer { self.clearLogs() }
    let logs: String
    switch logConfiguration {
    case .exact:
      logs = self.logs.label
    case .unordered:
      logs = self.logs.label.split(separator: "\n").sorted().joined(separator: "\n")
    }
    assertInlineSnapshot(
      of: logs,
      as: ._lines,
      matches: expectedLogs,
      file: file,
      function: function,
      line: line,
      column: column
    )
  }
}

enum LogConfiguration {
  case exact
  case unordered
}

extension Snapshotting where Value == String, Format == String {
  fileprivate static nonisolated(unsafe) let _lines = Snapshotting(
    pathExtension: "txt",
    diffing: Diffing(
      toData: { Data($0.utf8) },
      fromData: { String(decoding: $0, as: UTF8.self) }
    ) { old, new in
      guard old != new else { return nil }

      let newLines = new.split(separator: "\n", omittingEmptySubsequences: false)

      let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false)
      let difference = newLines.difference(from: oldLines)

      var result = ""

      var insertions = [Int: Substring]()
      var removals = [Int: Substring]()

      for change in difference {
        switch change {
        case let .insert(offset, element, _):
          insertions[offset] = element
        case let .remove(offset, element, _):
          removals[offset] = element
        }
      }

      var oldLine = 0
      var newLine = 0

      while oldLine < oldLines.count || newLine < newLines.count {
        if let removal = removals[oldLine] {
          result += "\(oldPrefix) \(removal)\n"
          oldLine += 1
        } else if let insertion = insertions[newLine] {
          result += "\(newPrefix) \(insertion)\n"
          newLine += 1
        } else {
          result += "\(prefix) \(oldLines[oldLine])\n"
          oldLine += 1
          newLine += 1
        }
      }

      let attachment = XCTAttachment(
        data: Data(result.utf8),
        uniformTypeIdentifier: "public.patch-file"
      )
      return (result, [attachment])
    }
  )
}

private let oldPrefix = "\u{2212}"
private let newPrefix = "+"
private let prefix = "\u{2007}"
