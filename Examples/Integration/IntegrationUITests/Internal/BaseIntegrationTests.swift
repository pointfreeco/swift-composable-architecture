import CustomDump
import XCTest

class BaseIntegrationTests: XCTestCase {
  var app: XCUIApplication!
  var logs: XCUIElement!
  private var _expectRuntimeWarnings: (file: StaticString, line: UInt)?

  func expectRuntimeWarnings(file: StaticString = #file, line: UInt = #line) {
    self._expectRuntimeWarnings = (file, line)
  }

  override func setUp() {
    self.continueAfterFailure = false
    self.app = XCUIApplication()
    self.app.launchEnvironment["UI_TEST"] = "true"
    self.app.launch()
    self.logs = self.app.staticTexts["composable-architecture.debug.logs"]
    // NB: When opening URLs through XCUIDevice the simulator will sometimes ask you to
    //     confirm opening. This taps on "Open" if such an alert appears.
    //
    //     More info: https://developer.apple.com/forums/thread/25355?answerId=765146022#765146022
    self.addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
      let open = alert.buttons.element(boundBy: 1)
      if open.exists {
        open.tap()
      }
      return true
    }
  }

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
      XCTAssertFalse(self.app.staticTexts["Runtime warning"].exists)
    }
  }

  func clearLogs() {
    XCUIDevice.shared.system.open(URL(string: "integration:///clear-logs")!)
  }

  func assertLogs(
    _ expectedLogs: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    defer { self.clearLogs() }
    XCTAssertNoDifference(
      self.logs.label,
      expectedLogs,
      file: file,
      line: line
    )
  }

  func assertLogs(
    _ expectedLogs: [Log],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    defer { self.clearLogs() }

    print(self.logs.label)
    var actualLogLines = self.logs.label.split(separator: "\n").map(String.init)
    var foundFailure = false
    for log in expectedLogs {
      switch log {
      case let .exact(logs):
        let logLines = logs.split(separator: "\n").map(String.init)
        if !actualLogLines.prefix(logLines.count).elementsEqual(logLines) {
          foundFailure = true
          break
        }
        actualLogLines.removeFirst(min(logLines.count, actualLogLines.count))
      case let .matching(logs):
        guard let logLines = try? logs.split(separator: "\n").map({ try Regex(String($0)) })
        else {
          foundFailure = true
          break
        }
        if zip(actualLogLines, logLines).allSatisfy({ $0.wholeMatch(of: $1) != nil }) {
          actualLogLines.removeFirst(min(logLines.count, actualLogLines.count))
        }
      case let .optional(logs):
        let logLines = logs.split(separator: "\n").map(String.init)
        if actualLogLines.prefix(logLines.count).starts(with: logLines) {
          actualLogLines.removeFirst(min(logLines.count, actualLogLines.count))
        }
      case let .unordered(logs):
        let logLines = logs.split(separator: "\n").map(String.init).sorted()
        guard logLines.count <= actualLogLines.count else {
          foundFailure = true
          break
        }
        for logLine in logLines {
          guard let index = actualLogLines.firstIndex(of: logLine)
          else {
            foundFailure = true
            break
          }
          actualLogLines.remove(at: index)
        }
      }
    }

    if foundFailure || !actualLogLines.isEmpty {
      XCTAssertNoDifference(
        self.logs.label,
        expectedLogs.map(\.description).joined(separator: "\n"),
        file: file,
        line: line
      )
    }
  }
}

enum Log: ExpressibleByStringLiteral, CustomStringConvertible {
  case exact(String)
  case matching(String)
  case optional(String)
  case unordered(String)
  init(stringLiteral value: String) {
    self = .exact(value)
  }
  var description: String {
    switch self {
    case let .exact(log), let .optional(log), let .matching(log), let .unordered(log):
      return log
    }
  }
}
