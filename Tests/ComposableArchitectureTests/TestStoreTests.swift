import Combine
import ComposableArchitecture
import XCTest

class TestStoreTests: XCTestCase {
  func testEffectConcatenation() {
    struct State: Equatable {}

    enum Action: Equatable {
      case a, b1, b2, b3, c1, c2, c3, d
    }

    let mainQueue = DispatchQueue.test

    let reducer = Reducer<State, Action, AnySchedulerOf<DispatchQueue>> { _, action, scheduler in
      switch action {
      case .a:
        return .merge(
          Effect.concatenate(.init(value: .b1), .init(value: .c1))
            .delay(for: 1, scheduler: scheduler)
            .eraseToEffect(),
          Empty(completeImmediately: false)
            .eraseToEffect()
            .cancellable(id: 1)
        )
      case .b1:
        return
          Effect
          .concatenate(.init(value: .b2), .init(value: .b3))
      case .c1:
        return
          Effect
          .concatenate(.init(value: .c2), .init(value: .c3))
      case .b2, .b3, .c2, .c3:
        return .none

      case .d:
        return .cancel(id: 1)
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: mainQueue.eraseToAnyScheduler()
    )

    store.send(.a)

    mainQueue.advance(by: 1)

    store.receive(.b1)
    store.receive(.b2)
    store.receive(.b3)

    store.receive(.c1)
    store.receive(.c2)
    store.receive(.c3)

    store.send(.d)
  }

  func testStateAccess() {
    enum Action { case a, b, c, d }
    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { count, action, _ in
        switch action {
        case .a:
          count += 1
          return .merge(.init(value: .b), .init(value: .c), .init(value: .d))
        case .b, .c, .d:
          count += 1
          return .none
        }
      },
      environment: ()
    )

    store.send(.a) {
      $0 = 1
      XCTAssertEqual(store.state, 0)
    }
    XCTAssertEqual(store.state, 1)
    store.receive(.b) {
      $0 = 2
      XCTAssertEqual(store.state, 1)
    }
    XCTAssertEqual(store.state, 2)
    store.receive(.c) {
      $0 = 3
      XCTAssertEqual(store.state, 2)
    }
    XCTAssertEqual(store.state, 3)
    store.receive(.d) {
      $0 = 4
      XCTAssertEqual(store.state, 3)
    }
    XCTAssertEqual(store.state, 4)
  }
}
