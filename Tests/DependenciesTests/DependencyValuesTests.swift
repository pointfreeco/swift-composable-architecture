import ComposableArchitecture
import XCTest

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {
    enum Key: TestDependencyKey {
      static let testValue = 42
    }

    var line = 0
    XCTExpectFailure {
      $0.compactDescription == """
        A dependency at DependenciesTests/DependencyValuesTests.swift:\(line) is being used in a \
        live environment without providing a live implementation:

          Key:
            DependencyValuesTests.Key
          Dependency:
            Int

        Every dependency registered with the library must conform to 'DependencyKey', and that \
        conformance must be visible to the running application.

        To fix, make sure that 'DependencyValuesTests.Key' conforms to 'DependencyKey' by \
        providing a live implementation of your dependency, and make sure that the conformance is \
        linked with this current application.
        """
    }

    line = #line + 1
    _ = DependencyValues.current[Key.self]
  }
}
