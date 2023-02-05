import ComposableArchitecture
import XCTest

final class TaskResultTests: XCTestCase {
  #if DEBUG
    func testEqualityNonEquatableError() {
      struct Failure: Error {
        let message: String
      }

      XCTExpectFailure {
        XCTAssertNotEqual(
          TaskResult<Never>.failure(Failure(message: "Something went wrong")),
          TaskResult<Never>.failure(Failure(message: "Something went wrong"))
        )
      } issueMatcher: {
        $0.compactDescription == """
          "TaskResultTests.Failure" is not equatable. …

          To test two values of this type, it must conform to the "Equatable" protocol. For example:

              extension TaskResultTests.Failure: Equatable {}

          See the documentation of "TaskResult" for more information.
          """
      }
    }

    func testEqualityMismatchingError() {
      struct Failure1: Error {
        let message: String
      }
      struct Failure2: Error {
        let message: String
      }

      XCTExpectFailure {
        XCTAssertNoDifference(
          TaskResult<Never>.failure(Failure1(message: "Something went wrong")),
          TaskResult<Never>.failure(Failure2(message: "Something went wrong"))
        )
      } issueMatcher: {
        $0.compactDescription == """
          XCTAssertNoDifference failed: …

              TaskResult.failure(
            −   TaskResultTests.Failure1(message: "Something went wrong")
            +   TaskResultTests.Failure2(message: "Something went wrong")
              )

          (First: −, Second: +)
          """
      }
    }

    func testHashabilityNonHashableError() {
      struct Failure: Error {
        let message: String
      }

      XCTExpectFailure {
        _ = TaskResult<Never>.failure(Failure(message: "Something went wrong")).hashValue
      } issueMatcher: {
        $0.compactDescription == """
          "TaskResultTests.Failure" is not hashable. …

          To hash a value of this type, it must conform to the "Hashable" protocol. For example:

              extension TaskResultTests.Failure: Hashable {}

          See the documentation of "TaskResult" for more information.
          """
      }
    }
  #endif

  func testEquality_EquatableError() {
    enum Failure: Error, Equatable {
      case message(String)
      case other
    }

    XCTAssertEqual(
      TaskResult<Never>.failure(Failure.message("Something went wrong")),
      TaskResult<Never>.failure(Failure.message("Something went wrong"))
    )
    XCTAssertNotEqual(
      TaskResult<Never>.failure(Failure.message("Something went wrong")),
      TaskResult<Never>.failure(Failure.message("Something else went wrong"))
    )
    XCTAssertEqual(
      TaskResult<Never>.failure(Failure.other),
      TaskResult<Never>.failure(Failure.other)
    )
    XCTAssertNotEqual(
      TaskResult<Never>.failure(Failure.other),
      TaskResult<Never>.failure(Failure.message("Uh oh"))
    )
  }

  func testHashable_HashableError() {
    enum Failure: Error, Hashable {
      case message(String)
      case other
    }

    let error1 = TaskResult<Int>.failure(Failure.message("Something went wrong"))
    let error2 = TaskResult<Int>.failure(Failure.message("Something else went wrong"))
    let statusByError = Dictionary(
      [
        (error1, 1),
        (error2, 2),
        (.failure(Failure.other), 3),
      ],
      uniquingKeysWith: { $1 }
    )

    XCTAssertEqual(Set(statusByError.values), [1, 2, 3])
    XCTAssertNotEqual(error1.hashValue, error2.hashValue)
  }
}
