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
  func testExpectedStateEquality() {
    struct State: Equatable {
      var count: Int = 0
      var isChanging: Bool = false
    }

    enum Action: Equatable {
      case increment
      case changed(from: Int, to: Int)
    }

    let reducer = Reducer<State, Action, Void> { state, action, scheduler in
      switch action {
      case .increment:
        state.isChanging = true
        return Effect(value: .changed(from: state.count, to: state.count + 1))
      case .changed(let from, let to):
        state.isChanging = false
        if state.count == from {
          state.count = to
        }
        return .none
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: ()
    )

    store.send(.increment) {
      $0.isChanging = true
    }
    store.receive(.changed(from: 0, to: 1)) {
      $0.isChanging = false
      $0.count = 1
    }

    XCTExpectFailure {
      store.send(.increment) {
        $0.isChanging = false
      }
    }
    XCTExpectFailure {
      store.receive(.changed(from: 1, to: 2)) {
        $0.isChanging = true
        $0.count = 1100
      }
    }
  }
  func testExpectedStateEqualityMustModify() {
    struct State: Equatable {
      var count: Int = 0
    }

    enum Action: Equatable {
      case noop, finished
    }

    let reducer = Reducer<State, Action, Void> { state, action, scheduler in
      switch action {
      case .noop:
        return Effect(value: .finished)
      case .finished:
        return .none
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer,
      environment: ()
    )

    store.send(.noop)
    store.receive(.finished)

    XCTExpectFailure {
      store.send(.noop) {
        $0.count = 0
      }
    }
    XCTExpectFailure {
      store.receive(.finished) {
        $0.count = 0
      }
    }
  }
}
