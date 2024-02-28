import Combine
import ComposableArchitecture
import XCTest

final class MemoryManagementTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  @available(*, deprecated)
  func testOwnership_ScopeHoldsOntoParent() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }
    let store = Store(initialState: 0) { counterReducer }
      .scope(state: { "\($0)" }, action: { $0 })
      .scope(state: { Int($0)! }, action: { $0 })
    let viewStore = ViewStore(store, observe: { $0 })

    var count = 0
    viewStore.publisher.sink { count = $0 }.store(in: &self.cancellables)

    XCTAssertEqual(count, 0)
    viewStore.send(())
    XCTAssertEqual(count, 1)
  }

  func testOwnership_ViewStoreHoldsOntoStore() {
    let counterReducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }
    let viewStore = ViewStore(Store(initialState: 0) { counterReducer }, observe: { $0 })

    var count = 0
    viewStore.publisher.sink { count = $0 }.store(in: &self.cancellables)

    XCTAssertEqual(count, 0)
    viewStore.send(())
    XCTAssertEqual(count, 1)
  }

  @available(*, deprecated)
  func testEffectWithMultipleScopes() {
    let expectation = self.expectation(description: "")

    enum Action { case tap, response }
    let store = Store(initialState: false) {
      Reduce<Bool, Action> { state, action in
        switch action {
        case .tap:
          state = false
          return .send(.response)
        case .response:
          state = true
          return .run { _ in
            expectation.fulfill()
          }
        }
      }
    }
    let viewStore = ViewStore(
      store
        .scope(state: { $0 }, action: { $0 })
        .scope(state: { $0 }, action: { $0 }),
      observe: { $0 }
    )

    var values: [Bool] = []
    viewStore.publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [false])
    viewStore.send(.tap)
    self.wait(for: [expectation], timeout: 1)
    XCTAssertEqual(values, [false, true])
  }
}
