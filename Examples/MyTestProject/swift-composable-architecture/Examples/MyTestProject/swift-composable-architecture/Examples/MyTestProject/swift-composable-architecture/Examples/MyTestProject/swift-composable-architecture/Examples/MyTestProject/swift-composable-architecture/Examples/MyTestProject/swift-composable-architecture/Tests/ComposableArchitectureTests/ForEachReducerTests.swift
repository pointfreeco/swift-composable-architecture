import ComposableArchitecture
import XCTest

@MainActor
final class ForEachReducerTests: XCTestCase {
  func testElementAction() async {
    let store = TestStore(
      initialState: Elements.State(
        rows: [
          .init(id: 1, value: "Blob"),
          .init(id: 2, value: "Blob Jr."),
          .init(id: 3, value: "Blob Sr."),
        ]
      ),
      reducer: Elements()
    )

    await store.send(.row(id: 1, action: "Blob Esq.")) {
      $0.rows[id: 1]?.value = "Blob Esq."
    }
    await store.send(.row(id: 2, action: "")) {
      $0.rows[id: 2]?.value = ""
    }
    await store.receive(.row(id: 2, action: "Empty")) {
      $0.rows[id: 2]?.value = "Empty"
    }
  }

  func testNonElementAction() async {
    let store = TestStore(
      initialState: Elements.State(),
      reducer: Elements()
    )

    await store.send(.buttonTapped)
  }

  #if DEBUG
    func testMissingElement() async {
      let store = TestStore(
        initialState: Elements.State(),
        reducer: EmptyReducer()
          .forEach(\.rows, action: /Elements.Action.row) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "\(#fileID):\(#line - 5)" received an action for a missing element.

            Action:
              Elements.Action.row(id:, action:)

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer removed an element with this ID before this reducer ran. This reducer \
          must run before any other reducer removes an element, which ensures that element reducers \
          can handle their actions while their state is still available.

          • An in-flight effect emitted this action when state contained no element at this ID. \
          While it may be perfectly reasonable to ignore this action, consider canceling the \
          associated effect before an element is removed, especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this ID. To \
          fix this make sure that actions for this reducer can only be sent from a view store when \
          its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
          """
      }

      await store.send(.row(id: 1, action: "Blob Esq."))
    }
  #endif
}

struct Elements: ReducerProtocol {
  struct State: Equatable {
    struct Row: Equatable, Identifiable {
      var id: Int
      var value: String
    }
    var rows: IdentifiedArrayOf<Row> = []
  }
  enum Action: Equatable {
    case buttonTapped
    case row(id: Int, action: String)
  }
  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      Reduce { state, action in
        .none
      }
      .forEach(\.rows, action: /Action.row) {
        Reduce { state, action in
          state.value = action
          return action.isEmpty
            ? .run { await $0("Empty") }
            : .none
        }
      }
    }
  #else
    var body: Reduce<State, Action> {
      Reduce { state, action in
        .none
      }
      .forEach(\.rows, action: /Action.row) {
        Reduce { state, action in
          state.value = action
          return action.isEmpty
            ? .run { await $0("Empty") }
            : .none
        }
      }
    }
  #endif
}
