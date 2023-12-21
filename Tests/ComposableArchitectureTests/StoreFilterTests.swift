import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

@MainActor
final class StoreInvalidationTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  func testInvalidation() {
    let store = Store<Int?, Void>(initialState: nil) {}
      .scope(
        state: ToState { $0 },
        id: nil,
        action: { $0 },
        isInvalid: { $0 != nil }
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
