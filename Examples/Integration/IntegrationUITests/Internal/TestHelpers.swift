import XCTest

@available(
  *,
  deprecated,
  message: "This is a test that currently fails but should not in the future."
)
func XCTTODO(_ message: String) {
  XCTExpectFailure(message)
}

extension XCUIElement {
  func find(
    timeout: TimeInterval = 0.3,
    filePath: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    if !self.waitForExistence(timeout: timeout) {
      XCTFail("Failed to find \(self).", file: filePath, line: line)
    }
    return self
  }
}
