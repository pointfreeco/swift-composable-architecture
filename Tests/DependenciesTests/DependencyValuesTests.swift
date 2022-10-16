import ComposableArchitecture
import XCTest

extension DependencyValues {
  fileprivate var missingLiveDependency: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }
}

private enum TestKey: TestDependencyKey {
  static let testValue = 42
}

extension DependencyValues {
  fileprivate var reusedDependency: Int {
    self[ReusedDependencyKey.self]
  }
}

private var reusedDependencyDefaultValue = 0
private enum ReusedDependencyKey: TestDependencyKey {
  static var testValue: Int {
    defer { reusedDependencyDefaultValue += 1 }
    return reusedDependencyDefaultValue
  }
}

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {
    #if DEBUG
      var line = 0
      XCTExpectFailure {
        var values = DependencyValues._current
        values.context = .live
        DependencyValues.$_current.withValue(values) {
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
  
  @Dependency(\.reusedDependency) var reusedDependency
  func testDependencyDefaultIsReused() {
    // Accessing `testValue` from `reusedDependency` returns `reusedDependencyDefaultValue` and
    // increments this value by 1.
    reusedDependencyDefaultValue = 42
    XCTAssertEqual(self.reusedDependency, 42)
    XCTAssertEqual(reusedDependencyDefaultValue, 43)
    // Access again. This shouldn't activate `testValue`.
    XCTAssertEqual(self.reusedDependency, 42)
    XCTAssertEqual(reusedDependencyDefaultValue, 43)
  }
}

private let someDate = Date(timeIntervalSince1970: 1_234_567_890)
