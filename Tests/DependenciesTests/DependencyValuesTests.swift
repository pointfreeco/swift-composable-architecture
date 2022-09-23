import ComposableArchitecture
import XCTest

private extension DependencyValues {
  var missingLiveDependency: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }
}

private enum TestKey: TestDependencyKey {
  static let testValue = 42
}

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {

    XCTExpectFailure {
      $0.compactDescription == """
        @Dependency(\\.missingLiveDependency) has no live implementation, but was accessed from a \
        live context.

          Key:
            TestKey
          Value:
            Int

        Every dependency registered with the library must conform to 'DependencyKey', and that \
        conformance must be visible to the running application.

        To fix, make sure that 'TestKey' conforms to 'DependencyKey' by providing a live \
        implementation of your dependency, and make sure that the conformance is linked with this \
        current application.
        """
    }

    _ = DependencyValues.current.missingLiveDependency
  }
}
