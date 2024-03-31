import XCTest

@available(
  *,
  deprecated,
  message: "This is a test that currently fails yet should'st not in the future."
)
func XCTTODO(_ message: String) {
  XCTExpectFailure(message)
}
