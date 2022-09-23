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

  func testDependencyKeyCascading_ImplementOnlyLiveValue() {
    struct Dependency: DependencyKey {
      let value: Int
      static let liveValue = Self(value: 42)
    }

    XCTAssertEqual(42, Dependency.liveValue.value)
    XCTAssertEqual(42, Dependency.previewValue.value)

    XCTExpectFailure {
      XCTAssertEqual(42, Dependency.testValue.value)
    } issueMatcher: { issue in
      issue.compactDescription == """
        A dependency has no test implementation, but was accessed from a test context:

          Dependency:
            DependencyKeyTests.Dependency

        Dependencies registered with the library are not allowed to use their live implementations \
        when run in a 'TestStore'.

        To fix, make sure that DependencyKeyTests.Dependency provides an implementation of \
        'testValue' in its conformance to the 'DependencyKey' protocol.
        """
    }
  }

  func testDependencyKeyCascading_ImplementOnlyLive() {
    enum Key: DependencyKey {
      static let liveValue = 42
    }

    XCTAssertEqual(42, Key.liveValue)
    XCTAssertEqual(42, Key.previewValue)

    XCTExpectFailure {
      XCTAssertEqual(42, Key.testValue)
    } issueMatcher: { issue in
      issue.compactDescription == """
        A dependency has no test implementation, but was accessed from a test context:

          Key:
            DependencyKeyTests.Key
          Value:
            Int

        Dependencies registered with the library are not allowed to use their live implementations \
        when run in a 'TestStore'.

        To fix, make sure that DependencyKeyTests.Key provides an implementation of 'testValue' in \
        its conformance to the 'DependencyKey' protocol.
        """
    }
  }

  func testDependencyKeyCascading_ImplementOnlyLiveAndPreviewValue() {
    enum Key: DependencyKey {
      static let liveValue = 42
      static let previewValue = 1729
    }

    XCTAssertEqual(42, Key.liveValue)
    XCTAssertEqual(1729, Key.previewValue)

    XCTExpectFailure {
      XCTAssertEqual(1729, Key.testValue)
    } issueMatcher: { issue in
      issue.compactDescription == """
        A dependency has no test implementation, but was accessed from a test context:

          Key:
            DependencyKeyTests.Key
          Value:
            Int

        Dependencies registered with the library are not allowed to use their live implementations \
        when run in a 'TestStore'.

        To fix, make sure that DependencyKeyTests.Key provides an implementation of 'testValue' in \
        its conformance to the 'DependencyKey' protocol.
        """
    }
  }

  func testDependencyKeyCascading_ImplementOnlyLive_Named() {
    DependencyValues.withValues {
      $0.context = .test
    } operation: {
      @Dependency(\.missingTestDependency) var missingTestDependency: Int
      let line = #line - 1
      XCTExpectFailure {
        XCTAssertEqual(42, missingTestDependency)
      } issueMatcher: { issue in
        issue.compactDescription == """
          @Dependency(\\.missingTestDependency) has no test implementation, but was accessed from \
          a test context:

            Location:
              DependenciesTests/DependencyKeyTests.swift:\(line)
            Key:
              LiveKey
            Value:
              Int

          Dependencies registered with the library are not allowed to use their live \
          implementations when run in a 'TestStore'.

          To fix, make sure that LiveKey provides an implementation of 'testValue' in its \
          conformance to the 'DependencyKey' protocol.
          """
      }
    }
  }
}

private enum LiveKey: DependencyKey {
  static let liveValue = 42
}

private extension DependencyValues {
  var missingTestDependency: Int {
    get { self[LiveKey.self] }
    set { self[LiveKey.self] = newValue }
  }
}
