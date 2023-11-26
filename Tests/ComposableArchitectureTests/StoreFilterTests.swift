#if DEBUG
  import Combine
  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  final class StoreInvalidationTests: BaseTCATestCase {
    var cancellables: Set<AnyCancellable> = []

    func testInvalidation() {
      let store = Store<Int?, Void>(initialState: nil) {}
        .scope(
          state: { $0 },
          id: nil,
          action: { $0 },
          isInvalid: { $0 != nil },
          removeDuplicates: nil
        )
      let viewStore = ViewStore(store, observe: { $0 })
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
