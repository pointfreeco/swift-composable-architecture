import Combine
import ComposableArchitecture
import XCTest

final class ViewStoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  override func setUp() {
    super.setUp()
    equalityChecks = 0
  }

  func testPublisherFirehose() {
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Void, Void>.empty,
      environment: ()
    )

    let viewStore = ViewStore(store)

    var count = 0
    viewStore.publisher
      .sink { _ in count += 1 }
      .store(in: &self.cancellables)

    XCTAssertEqual(count, 1)

    viewStore.send(())
    XCTAssertEqual(count, 1)

    viewStore.send(())
    XCTAssertEqual(count, 1)

    viewStore.send(())
    XCTAssertEqual(count, 1)
  }

  func testEqualityChecks() {
    let store = Store(
      initialState: State(),
      reducer: Reducer<State, Void, Void>.empty,
      environment: ()
    )

    let store1 = store.scope(state: { $0 })
    let store2 = store1.scope(state: { $0 })
    let store3 = store2.scope(state: { $0 })
    let store4 = store3.scope(state: { $0 })

    let viewStore1 = ViewStore(store1)
    let viewStore2 = ViewStore(store2)
    let viewStore3 = ViewStore(store3)
    let viewStore4 = ViewStore(store4)

    viewStore1.publisher
      .sink { _ in }
      .store(in: &self.cancellables)
    viewStore2.publisher
      .sink { _ in }
      .store(in: &self.cancellables)
    viewStore3.publisher
      .sink { _ in }
      .store(in: &self.cancellables)
    viewStore4.publisher
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(0, equalityChecks)

    viewStore4.send(())

    XCTAssertEqual(28, equalityChecks)

    viewStore4.send(())

    XCTAssertEqual(56, equalityChecks)

    viewStore4.send(())

    XCTAssertEqual(84, equalityChecks)

    viewStore4.send(())

    XCTAssertEqual(112, equalityChecks)
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
