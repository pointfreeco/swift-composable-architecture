  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  final class BindingActionTests: BaseTCATestCase {
    public func testEquality_BindingState() {
      struct User {
        @BindingState var name = ""
      }

      let action = BindingAction.set(\User.$name, "Blob")
      XCTAssertEqual(
        action,
        .set(\.$name, "Blob")
      )

      XCTAssertNotEqual(
        action,
        .set(\.$name, "Blob, Jr.")
      )
    }

    #if swift(>=5.9)
      @ObservableState
      struct ObservableUser {
        var name = ""
      }

      public func testEquality_ObservableState() {
        let action = BindingAction.set(\ObservableUser.name, "Blob")
        XCTAssertEqual(
          action,
          .set(\.name, "Blob")
        )

        XCTAssertNotEqual(
          action,
          .set(\.name, "Blob, Jr.")
        )
      }
    #endif
  }
