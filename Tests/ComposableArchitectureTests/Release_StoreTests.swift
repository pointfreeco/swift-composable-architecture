import Combine
import ComposableArchitecture
import XCTest

final class Release_StoreTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testMultipleScopes() {
    let expectation = self.expectation(description: "")
 
    enum Action { case tap, response }
    let store = Store(
      initialState: false,
      reducer: Reduce<Bool, Action> { state, action in
        switch action {
        case .tap:
          state = false
          return .task { .response }
        case .response:
          state = true
          return .fireAndForget {
            expectation.fulfill()
          }
        }
      }
    )
    let viewStore = ViewStore(store.scope(state: { $0 }).scope(state: { $0 }))

    var values: [Bool] = []
    viewStore.publisher
      .sink(receiveValue: { values.append($0 )})
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [false])
    viewStore.send(.tap)
    self.wait(for: [expectation], timeout: 1)
    XCTAssertEqual(values, [false, true])
  }
}
