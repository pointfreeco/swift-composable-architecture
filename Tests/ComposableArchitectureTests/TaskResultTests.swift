import ComposableArchitecture
import XCTest

class TaskResultTests: XCTestCase {
  func testEqualityNonEquatableError() {
    struct Error: Swift.Error {
      let message: String
    }

    XCTAssertEqual(
      TaskResult<Never>.failure(Error(message: "Something went wrong")),
      TaskResult<Never>.failure(Error(message: "Something went wrong"))
    )
  }

  func testEqualityNonEquatableError_NonObjcBrided() {
    enum Error: Swift.Error {
      case message(String)
      case other
    }

    XCTAssertEqual(
      TaskResult<Never>.failure(Error.message("Something went wrong")),
      TaskResult<Never>.failure(Error.message("Something went wrong"))
    )
    XCTAssertEqual(
      TaskResult<Never>.failure(Error.message("Something went wrong")),
      TaskResult<Never>.failure(Error.message("Something else went wrong"))
    )
    XCTAssertEqual(
      TaskResult<Never>.failure(Error.other),
      TaskResult<Never>.failure(Error.other)
    )
    XCTAssertNotEqual(
      TaskResult<Never>.failure(Error.other),
      TaskResult<Never>.failure(Error.message("Uh oh"))
    )
  }

  func testEqualityEquatableError() {
    enum Error: Swift.Error, Equatable {
      case message(String)
      case other
    }

    XCTAssertEqual(
      TaskResult<Never>.failure(Error.message("Something went wrong")),
      TaskResult<Never>.failure(Error.message("Something went wrong"))
    )
    // TODO: why does this fail?
    XCTAssertNotEqual(
      TaskResult<Never>.failure(Error.message("Something went wrong")),
      TaskResult<Never>.failure(Error.message("Something else went wrong"))
    )
    XCTAssertEqual(
      TaskResult<Never>.failure(Error.other),
      TaskResult<Never>.failure(Error.other)
    )
    XCTAssertNotEqual(
      TaskResult<Never>.failure(Error.other),
      TaskResult<Never>.failure(Error.message("Uh oh"))
    )
  }
}
