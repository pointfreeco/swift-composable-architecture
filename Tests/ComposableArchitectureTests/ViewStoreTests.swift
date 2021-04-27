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

    let store1 = store.scope(state: { $0 })
    let store2 = store1.scope(state: { $0 })
    let store3 = store2.scope(state: { $0 })
    let store4 = store3.scope(state: { $0 })

    let viewStore1 = ViewStore(store1)
//    let viewStore2 = ViewStore(store2)
//    let viewStore3 = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    XCTAssertEqual(0, equalityChecks)

    viewStore1.publisher.name
      .sink { _ in }
      .store(in: &self.cancellables)
//    viewStore2.publisher.name
//      .sink { _ in }
//      .store(in: &self.cancellables)
//    viewStore3.publisher.name
//      .sink { _ in }
//      .store(in: &self.cancellables)
    viewStore4.publisher.name
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(0, equalityChecks)

    viewStore1.send(true)

    XCTAssertEqual(1, equalityChecks)

    viewStore1.send(true)

    XCTAssertEqual(2, equalityChecks)

    viewStore1.send(true)

    XCTAssertEqual(3, equalityChecks)

    viewStore1.send(true)

    XCTAssertEqual(4, equalityChecks)
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
