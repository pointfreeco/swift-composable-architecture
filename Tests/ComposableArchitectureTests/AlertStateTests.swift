import ComposableArchitecture
import XCTest

final class AlertStateTests: XCTestCase {
  func test_text_equatable() {
    let values: [AlertState<Void>.Text] = [
      .localized(.init("key")),
      .verbatim("verbatim")
    ]

    values.enumerated().forEach { (lhsIndex, lhs) in
      values.enumerated().forEach { (rhsIndex, rhs) in
        XCTAssertEqual(lhsIndex == rhsIndex, lhs == rhs, "\(lhs) != \(rhs)")
      }
    }
  }
}
