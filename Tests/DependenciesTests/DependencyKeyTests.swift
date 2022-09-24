import ComposableArchitecture
import XCTest

final class DependencyKeyTests: XCTestCase {
  func testTestDependencyKey_ImplementOnlyTestValue() {
    enum Key: TestDependencyKey {
      static let testValue = 42
    }

    XCTAssertEqual(42, Key.previewValue)
    XCTAssertEqual(42, Key.testValue)
  }

  func testDependencyKeyCascading_ValueIsSelf_ImplementOnlyLiveValue() {
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
          A dependency has no test implementation, but was accessed from a test context:

            Dependency:
              DependencyKeyTests.Dependency

          Dependencies registered with the library are not allowed to use their live \
          implementations when run in a 'TestStore'.

          There are two ways to fix:

          • Make DependencyKeyTests.Dependency provide an implementation of 'testValue' in its \
          conformance to the 'DependencyKey' protocol.
          • Override the dependency with a mock in your test by mutating the 'dependencies' \
          property on your 'TestStore'.
          """
      }
    #endif
  }

  func testDependencyKeyCascading_ImplementOnlyLiveValue() {
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
          A dependency has no test implementation, but was accessed from a test context:

            Key:
              DependencyKeyTests.Key
            Value:
              Int

          Dependencies registered with the library are not allowed to use their live \
          implementations when run in a 'TestStore'.

          There are two ways to fix:

          • Make DependencyKeyTests.Key provide an implementation of 'testValue' in its \
          conformance to the 'DependencyKey' protocol.
          • Override the dependency with a mock in your test by mutating the 'dependencies' \
          property on your 'TestStore'.
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
          A dependency has no test implementation, but was accessed from a test context:

            Key:
              DependencyKeyTests.Key
            Value:
              Int

          Dependencies registered with the library are not allowed to use their live implementations \
          when run in a 'TestStore'.

          There are two ways to fix:

          • Make DependencyKeyTests.Key provide an implementation of 'testValue' in its \
          conformance to the 'DependencyKey' protocol.
          • Override the dependency with a mock in your test by mutating the 'dependencies' \
          property on your 'TestStore'.
          """
      }
    #endif
  }

  func testDependencyKeyCascading_ImplementOnlyLive_Named() {
    #if DEBUG
      DependencyValues.withValues {
        $0.context = .test
      } operation: {
        @Dependency(\.missingTestDependency) var missingTestDependency: Int
        let line = #line - 1
        XCTExpectFailure {
          XCTAssertEqual(42, missingTestDependency)
        } issueMatcher: { issue in
          issue.compactDescription == """
            @Dependency(\\.missingTestDependency) has no test implementation, but was accessed \
            from a test context:

              Location:
                DependenciesTests/DependencyKeyTests.swift:\(line)
              Key:
                LiveKey
              Value:
                Int

            Dependencies registered with the library are not allowed to use their live \
            implementations when run in a 'TestStore'.

            There are two ways to fix:

            • Make LiveKey provide an implementation of 'testValue' in its \
            conformance to the 'DependencyKey' protocol.
            • Override 'missingTestDependency' with a mock in your test by mutating the \
            'dependencies' property on your 'TestStore'.
            """
        }
    }
    #endif
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
