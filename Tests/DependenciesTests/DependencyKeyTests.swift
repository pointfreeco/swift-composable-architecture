import ComposableArchitecture
import XCTest

final class DependencyKeyTests: XCTestCase {
  func testTestDependencyKeyCascading() {
    enum Key: TestDependencyKey {
      static let testValue = 42
    }

    XCTAssertEqual(42, Key.previewValue)
    XCTAssertEqual(42, Key.testValue)
  }

  func testDependencyKeyCascading_ValueIsSelf_ImplementOnlyLive() {
    struct Dependency: DependencyKey {
      let value: Int
      static let liveValue = Self(value: 42)
    }

    XCTAssertEqual(42, Dependency.liveValue.value)
    XCTAssertEqual(42, Dependency.previewValue.value)

    #if DEBUG
      XCTExpectFailure {
        XCTAssertEqual(42, Dependency.testValue.value)
      } issueMatcher: { issue in
        issue.compactDescription == """
          A dependency is being used in a test environment without providing a test implementation:

            Dependency:
              DependencyKeyTests.Dependency

          Dependencies registered with the library are not allowed to use their live implementations \
          when run in a 'TestStore'.

          To fix, make sure that DependencyKeyTests.Dependency provides an implementation of \
          'testValue' in its conformance to the 'DependencyKey` protocol.
          """
      }
    #endif
  }

  func testDependencyKeyCascading_ImplementOnlyLive() {
    enum Key: DependencyKey {
      static let liveValue = 42
    }

    XCTAssertEqual(42, Key.liveValue)
    XCTAssertEqual(42, Key.previewValue)

    #if DEBUG
      XCTExpectFailure {
        XCTAssertEqual(42, Key.testValue)
      } issueMatcher: { issue in
        issue.compactDescription == """
          A dependency is being used in a test environment without providing a test implementation:

            Key:
              DependencyKeyTests.Key
            Dependency:
              Int

          Dependencies registered with the library are not allowed to use their live implementations \
          when run in a 'TestStore'.

          To fix, make sure that DependencyKeyTests.Key provides an implementation of 'testValue' in \
          its conformance to the 'DependencyKey` protocol.
          """
      }
    #endif
  }

  func testDependencyKeyCascading_ImplementOnlyLiveAndPreviewValue() {
    enum Key: DependencyKey {
      static let liveValue = 42
      static let previewValue = 1729
    }

    XCTAssertEqual(42, Key.liveValue)
    XCTAssertEqual(1729, Key.previewValue)

    #if DEBUG
      XCTExpectFailure {
        XCTAssertEqual(1729, Key.testValue)
      } issueMatcher: { issue in
        issue.compactDescription == """
          A dependency is being used in a test environment without providing a test implementation:

            Key:
              DependencyKeyTests.Key
            Dependency:
              Int

          Dependencies registered with the library are not allowed to use their live implementations \
          when run in a 'TestStore'.

          To fix, make sure that DependencyKeyTests.Key provides an implementation of 'testValue' in \
          its conformance to the 'DependencyKey` protocol.
          """
      }
    #endif
  }
}
