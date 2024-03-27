import XCTest

@_transparent
@available(
  *,
  deprecated,
  message: "This is a test that currently fails but should not in the future."
)
func XCTTODO(_ message: String) {
  XCTExpectFailure(message)
}
