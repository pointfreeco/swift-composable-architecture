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
    file: StaticString = #file,
    line: UInt = #line
  ) -> XCUIElement {
    if !self.waitForExistence(timeout: timeout) {
      XCTFail("Failed to find \(self).", file: file, line: line)
    }
    return self
  }
}
