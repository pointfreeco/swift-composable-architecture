import Foundation

#if os(Windows)
import XCTest

func XCTSkipIfWindowsExpectFailure(file: StaticString = #fileID, line: UInt = #line) throws {
  throw XCTSkip("XCTExpectFailure is currently not supported on Windows.", file: file, line: line)
}

struct XCTIssue {
  var compactDescription: String
}

@_disfavoredOverload
func XCTExpectFailure<R>(
  _ failureReason: String? = nil,
  enabled: Bool? = nil,
  strict: Bool? = nil,
  failingBlock: () throws -> R,
  issueMatcher: ((XCTIssue) -> Bool)? = nil,
  file: StaticString = #fileID,
  line: UInt = #line
) rethrows -> R? {
  print(warnFail(message: failureReason ?? ""))
  return nil
}

@_disfavoredOverload
func XCTExpectFailure(
  _ failureReason: String? = nil,
  enabled: Bool? = nil,
  strict: Bool? = nil,
  issueMatcher: ((XCTIssue) -> Bool)? = nil,
  file: StaticString = #fileID,
  line: UInt = #line
) {
  print(warnFail(message: failureReason ?? ""))
}

private func warnFail(message: String) -> String {
  return """
    XCTExpectFailure: \(message)

    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┉┅
    ┃ ⚠︎ Warning: This XCTExpectFailure was ignored.
    ┃
    ┃ XCTExpectFailure is currently not supported on Windows.
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┉┅
        ▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄
    """
}
#else

func XCTSkipIfWindowsExpectFailure(file: StaticString = #fileID, line: UInt = #line) throws {}

#endif
