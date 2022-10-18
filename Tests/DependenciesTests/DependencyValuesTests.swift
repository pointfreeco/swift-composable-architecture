import Dependencies
import XCTest

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {
    #if DEBUG
      var line = 0
      XCTExpectFailure {
        DependencyValues.withValue(\.context, .live) {
          line = #line + 1
          @Dependency(\.missingLiveDependency) var missingLiveDependency: Int
          _ = missingLiveDependency
        }
      } issueMatcher: {
        $0.compactDescription == """
          "@Dependency(\\.missingLiveDependency)" has no live implementation, but was accessed \
          from a live context.

            Location:
              DependenciesTests/DependencyValuesTests.swift:\(line)
            Key:
              TestKey
            Value:
              Int

          Every dependency registered with the library must conform to "DependencyKey", and that \
          conformance must be visible to the running application.

          To fix, make sure that "TestKey" conforms to "DependencyKey" by providing a live \
          implementation of your dependency, and make sure that the conformance is linked with \
          this current application.
          """
      }
    #endif
  }

  func testWithValues() {
    let date = DependencyValues.withValues {
      $0.date = .constant(someDate)
    } operation: { () -> Date in
      @Dependency(\.date) var date
      return date.now
    }

    let defaultDate = DependencyValues.withValues {
      $0.context = .live
    } operation: { () -> Date in
      @Dependency(\.date) var date
      return date.now
    }

    XCTAssertEqual(date, someDate)
    XCTAssertNotEqual(defaultDate, someDate)
  }

  func testWithValue() {
    DependencyValues.withValue(\.context, .live) {
      let date = DependencyValues.withValue(\.date, .constant(someDate)) { () -> Date in
        @Dependency(\.date) var date
        return date.now
      }

      XCTAssertEqual(date, someDate)
      XCTAssertNotEqual(DependencyValues._current.date.now, someDate)
    }
  }

  func testDependencyDefaultIsReused() {
    DependencyValues.withValue(\.self, .init()) {
      @Dependency(\.reuseClient) var reuseClient: ReuseClient

      XCTAssertEqual(reuseClient.count(), 0)
      reuseClient.setCount(42)
      XCTAssertEqual(reuseClient.count(), 42)
    }
  }

  func testDependencyDefaultIsReused_SegmentedByContext() {
    DependencyValues.withValue(\.self, .init()) {
      @Dependency(\.reuseClient) var reuseClient: ReuseClient

      XCTAssertEqual(reuseClient.count(), 0)
      reuseClient.setCount(42)
      XCTAssertEqual(reuseClient.count(), 42)

      DependencyValues.withValue(\.context, .preview) {
        XCTAssertEqual(reuseClient.count(), 0)
        reuseClient.setCount(1729)
        XCTAssertEqual(reuseClient.count(), 1729)
      }

      XCTAssertEqual(reuseClient.count(), 42)

      DependencyValues.withValue(\.context, .live) {
        #if DEBUG
          XCTExpectFailure {
            $0.compactDescription.contains(
              """
              @Dependency(\\.reuseClient)" has no live implementation, but was accessed from a live \
              context.
              """
            )
          }
        #endif
        XCTAssertEqual(reuseClient.count(), 0)
        reuseClient.setCount(-42)
        XCTAssertEqual(
          reuseClient.count(),
          0,
          "Don't cache dependency when using a test value in a live context"
        )
      }

      XCTAssertEqual(reuseClient.count(), 42)
    }
  }

  func testAccessingTestDependencyFromLiveContext_WhenUpdatingDependencies() {
    @Dependency(\.reuseClient) var reuseClient: ReuseClient

    DependencyValues.withValue(\.context, .live) {
      DependencyValues.withValues {
        XCTAssertEqual($0.reuseClient.count(), 0)
        XCTAssertEqual(reuseClient.count(), 0)
      } operation: {
        #if DEBUG
          XCTExpectFailure {
            $0.compactDescription.contains(
              """
              @Dependency(\\.reuseClient)" has no live implementation, but was accessed from a live \
              context.
              """
            )
          }
        #endif
        XCTAssertEqual(reuseClient.count(), 0)
      }
    }
  }
}

private let someDate = Date(timeIntervalSince1970: 1_234_567_890)

extension DependencyValues {
  fileprivate var missingLiveDependency: Int {
    self[TestKey.self]
  }
}

private enum TestKey: TestDependencyKey {
  static let testValue = 42
}

extension DependencyValues {
  fileprivate var reuseClient: ReuseClient {
    get { self[ReuseClient.self] }
    set { self[ReuseClient.self] = newValue }
  }
}
struct ReuseClient: TestDependencyKey {
  var count: () -> Int
  var setCount: (Int) -> Void
  init(
    count: @escaping () -> Int,
    setCount: @escaping (Int) -> Void
  ) {
    self.count = count
    self.setCount = setCount
  }
  static var testValue: Self {
    var count = 0
    return Self(
      count: { count },
      setCount: { count = $0 }
    )
  }
}
