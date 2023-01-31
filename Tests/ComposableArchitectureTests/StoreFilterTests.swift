#if DEBUG
  import Combine
  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  final class StoreFilterTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    func testFilter() {
      let store = Store<Int?, Void>(initialState: nil, reducer: EmptyReducer())
        .filter { state, _ in state != nil }

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
    }
  }
#endif
