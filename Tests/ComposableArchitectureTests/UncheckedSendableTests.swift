import ComposableArchitecture
import XCTest

class UncheckedSendableTests: XCTestCase {
  func testNotSendable() {
    class Foo { var bar: Int? }

    _ = UncheckedSendable(Foo())
  }

  func testNotSendablePropertyWrapper() {
    class Foo { var bar: Int? }

    @UncheckedSendable var foo = Foo()
    _ = foo
  }

  func testAlreadySendableWarning() {
    struct Foo: Sendable {}

    XCTExpectFailure {
      _ = UncheckedSendable(Foo())
    } issueMatcher: {
      $0.compactDescription == """
        'Foo' already conforms to the 'Sendable' protocol. There is no need to wrap values of \
        'Foo' with 'UncheckedSendable'.
        """
    }
  }

  func testAlreadySendableWarningPropertyWrapper() {
    struct Foo: Sendable {}

    XCTExpectFailure {
      @UncheckedSendable var foo = Foo()
      _ = foo
    } issueMatcher: {
      $0.compactDescription == """
        'Foo' already conforms to the 'Sendable' protocol. There is no need to wrap values of \
        'Foo' with 'UncheckedSendable'.
        """
    }
  }
}
