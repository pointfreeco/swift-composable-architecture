import ComposableArchitecture
import XCTest

final class DependencyKeyTests: XCTestCase {
  func testTestDependencyKeyDefaultPreviewValue() {
    enum Key: TestDependencyKey {
      typealias Value = Int
      static let testValue = 42
    }

    XCTAssertEqual(42, Key.previewValue)
  }

  func testDependencyKeyDefaultValues() {
    enum Key: DependencyKey {
      typealias Value = Int
      static let liveValue = 42
    }

    XCTAssertEqual(42, Key.previewValue)
    XCTAssertEqual(42, Key.testValue)
  }

  func testDependencyKeyDefaultPreviewValue() {
    enum Key: DependencyKey {
      typealias Value = Int
      static let liveValue = 42
      static let testValue = 1729
    }

    XCTAssertEqual(42, Key.previewValue)
  }
}
