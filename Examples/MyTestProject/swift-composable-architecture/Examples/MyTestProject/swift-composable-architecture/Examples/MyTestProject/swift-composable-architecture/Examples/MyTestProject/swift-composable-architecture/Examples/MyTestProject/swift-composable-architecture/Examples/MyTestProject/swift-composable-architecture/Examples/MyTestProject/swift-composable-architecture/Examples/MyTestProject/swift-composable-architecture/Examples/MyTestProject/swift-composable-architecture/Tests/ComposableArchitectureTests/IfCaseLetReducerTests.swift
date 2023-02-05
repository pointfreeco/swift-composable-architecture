import ComposableArchitecture
import XCTest

@MainActor
final class IfCaseLetReducerTests: XCTestCase {
  func testChildAction() async {
    struct SomeError: Error, Equatable {}

    let store = TestStore(
      initialState: Result.success(0),
      reducer: Reduce<Result<Int, SomeError>, Result<Int, SomeError>> { state, action in
        .none
      }
      .ifCaseLet(/Result.success, action: /Result.success) {
        Reduce { state, action in
          state = action
          return state < 0 ? .run { await $0(0) } : .none
        }
      }
    )

    await store.send(.success(1)) {
      $0 = .success(1)
    }
    await store.send(.failure(SomeError()))
    await store.send(.success(-1)) {
      $0 = .success(-1)
    }
    await store.receive(.success(0)) {
      $0 = .success(0)
    }
  }

  #if DEBUG
    func testNilChild() async {
      struct SomeError: Error, Equatable {}

      let store = TestStore(
        initialState: Result.failure(SomeError()),
        reducer: EmptyReducer<Result<Int, SomeError>, Result<Int, SomeError>>()
          .ifCaseLet(/Result.success, action: /Result.success) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
          An "ifCaseLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
          set to a different case. …

            Action:
              Result.success
            State:
              Result.failure

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer set "Result" to a different case before this reducer ran. This reducer \
          must run before any other reducer sets child state to a different case. This ensures that \
          child reducers can handle their actions while their state is still available.

          • An in-flight effect emitted this action when child state was unavailable. While it may \
          be perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state changes to another case, especially if it is a long-living effect.

          • This action was sent to the store while state was another case. Make sure that actions \
          for this reducer can only be sent from a view store when state is set to the appropriate \
          case. In SwiftUI applications, use "SwitchStore".
          """
      }

      await store.send(.success(1))
    }
  #endif
}
