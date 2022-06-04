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

  func testEquality_NonEquatableError_NonObjCBrided() {
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

  func testEquality_EquatableError() {
    enum Error: Swift.Error, Equatable {
      case message(String)
      case other
    }

    XCTAssertEqual(
      TaskResult<Never>.failure(Error.message("Something went wrong")),
      TaskResult<Never>.failure(Error.message("Something went wrong"))
    )
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

  func testHashable_NonHashableError_NonObjCBridged() {
    enum Error: Swift.Error {
      case message(String)
      case other
    }

    let error1 = TaskResult<Int>.failure(Error.message("Something went wrong"))
    let error2 = TaskResult<Int>.failure(Error.message("Something else went wrong"))
    let statusByError = Dictionary(
      [
        (error1, 1),
        (error2, 2),
        (.failure(Error.other), 3),
      ],
      uniquingKeysWith: { $1 }
    )

    XCTAssertEqual(Set(statusByError.values), [2, 3])
    XCTAssertEqual(error1.hashValue, error2.hashValue)
  }

  func testHashable_HashableError() {
    enum Error: Swift.Error, Hashable {
      case message(String)
      case other
    }

    let error1 = TaskResult<Int>.failure(Error.message("Something went wrong"))
    let error2 = TaskResult<Int>.failure(Error.message("Something else went wrong"))
    let statusByError = Dictionary(
      [
        (error1, 1),
        (error2, 2),
        (.failure(Error.other), 3),
      ],
      uniquingKeysWith: { $1 }
    )

    XCTAssertEqual(Set(statusByError.values), [1, 2, 3])
    XCTAssertNotEqual(error1.hashValue, error2.hashValue)
  }
}
