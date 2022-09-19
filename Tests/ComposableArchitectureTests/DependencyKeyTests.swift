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
  
  //TODO: intentionally long naming. I think we don't need this test. Its just there to prove that the improved TestDependencyKey protocol now compiles without a typealias when `Value == Self`
  func testDependencyKeyThatsItsOwnValueDefaultValues() {
    struct Key: DependencyKey {
//      typealias Value = Int
      static let liveValue = Self()
      var intValue: Int = 42
    }

    XCTAssertEqual(42, Key.previewValue.intValue)
    XCTAssertEqual(42, Key.testValue.intValue)
  }

}
