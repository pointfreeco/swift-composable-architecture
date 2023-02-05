import ComposableArchitecture
import XCTest

@MainActor
final class IfLetReducerTests: XCTestCase {
  #if DEBUG
    func testNilChild() async {
      let store = TestStore(
        initialState: Int?.none,
        reducer: EmptyReducer<Int?, Void>()
          .ifLet(\.self, action: /.self) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
          An "ifLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
          "nil". …

            Action:
              ()

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer set child state to "nil" before this reducer ran. This reducer must run \
          before any other reducer sets child state to "nil". This ensures that child reducers can \
          handle their actions while their state is still available.

          • An in-flight effect emitted this action when child state was "nil". While it may be \
          perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state becomes "nil", especially if it is a long-living effect.

          • This action was sent to the store while state was "nil". Make sure that actions for this \
          reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
          applications, use "IfLetStore".
          """
      }

      await store.send(())
    }
  #endif
}
