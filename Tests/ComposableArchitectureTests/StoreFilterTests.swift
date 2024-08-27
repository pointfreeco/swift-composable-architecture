import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class StoreInvalidationTests: BaseTCATestCase {
  func testInvalidation() {
    var cancellables: Set<AnyCancellable> = []

    let store = Store<Int?, Void>(initialState: nil) {}
      .scope(
        id: nil,
        state: ToState { $0 },
        action: { $0 },
        isInvalid: { $0 != nil }
      )
    let viewStore = ViewStore(store, observe: { $0 })
    var count = 0
    viewStore.publisher
      .sink { _ in count += 1 }
      .store(in: &cancellables)

    XCTAssertEqual(count, 1)
    viewStore.send(())
    XCTAssertEqual(count, 1)
    viewStore.send(())
    XCTAssertEqual(count, 1)
  }
}
