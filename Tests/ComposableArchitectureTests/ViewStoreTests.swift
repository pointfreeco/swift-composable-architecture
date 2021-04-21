import Combine
import ComposableArchitecture
import XCTest

final class ViewStoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testRemoveDuplicates() {
//    struct ParentState: Equatable {
//      var child = ChildState()
//
//      static func == (lhs: Self, rhs: Self) -> Bool {
//        parentChecks += 1
//        return lhs.child == rhs.child
//      }
//    }

    let store = Store(
      initialState: ChildState(),
      reducer: Reducer<ChildState, Bool, Void> { state, action, _ in
        if action {
          state.name = state.name + " " + state.name
        }
        return .none
      },
      environment: ()
    )

    let viewStore = ViewStore(store.scope(state: { $0 }).scope(state: { $0 }))

    XCTAssertEqual(0, childChecks)

    viewStore.publisher.name
      .sink { _ in
        print("ok")
      }
      .store(in: &self.cancellables)

    XCTAssertEqual(0, childChecks)

    viewStore.send(true)

    XCTAssertEqual(1, childChecks)

    viewStore.send(true)

    XCTAssertEqual(2, childChecks)

    viewStore.send(true)

    XCTAssertEqual(3, childChecks)

    viewStore.send(true)

    XCTAssertEqual(4, childChecks)

    viewStore.send(true)

    XCTAssertEqual(5, childChecks)

    viewStore.send(true)

    XCTAssertEqual(6, childChecks)

    viewStore.send(true)

    XCTAssertEqual(7, childChecks)
  }
}

private struct ChildState: Equatable {
  var name = "Blob"

  static func == (lhs: Self, rhs: Self) -> Bool {
    childChecks += 1
    return lhs.name == rhs.name
  }
}

private var childChecks = 0
private var parentChecks = 0
