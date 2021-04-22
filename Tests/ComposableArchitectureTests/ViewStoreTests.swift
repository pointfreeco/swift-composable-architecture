import Combine
import ComposableArchitecture
import XCTest

final class ViewStoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCallCount() {
    
  }

  func testRemoveDuplicates() {
    let store = Store(
      initialState: State(),
      reducer: Reducer<State, Bool, Void> { state, action, _ in
        if action {
          state.name = state.name + " " + state.name
        }
        return .none
      },
      environment: ()
    )

    let viewStore = ViewStore(store.scope(state: { $0 }).scope(state: { $0 }).scope(state: { $0 }))

    XCTAssertEqual(0, equalityChecks)

    viewStore.publisher.name
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(0, equalityChecks)

    viewStore.send(true)

    XCTAssertEqual(1, equalityChecks)

    viewStore.send(true)

    XCTAssertEqual(2, equalityChecks)

    viewStore.send(true)

    XCTAssertEqual(3, equalityChecks)
  }
}

private struct State: Equatable {
  var name = "Blob"

  static func == (lhs: Self, rhs: Self) -> Bool {
    equalityChecks += 1
    return lhs.name == rhs.name
  }
}

private var equalityChecks = 0
