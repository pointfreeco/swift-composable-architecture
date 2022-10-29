import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class TestStoreTests: XCTestCase {
  func testEffectConcatenation() async {
    struct State: Equatable {}

    enum Action: Equatable {
      case a, b1, b2, b3, c1, c2, c3, d
    }

    let mainQueue = DispatchQueue.test

    let reducer = Reduce<State, Action> { _, action in
      switch action {
      case .a:
        return .merge(
          EffectTask.concatenate(.init(value: .b1), .init(value: .c1))
            .delay(for: 1, scheduler: mainQueue)
            .eraseToEffect(),
          Empty(completeImmediately: false)
            .eraseToEffect()
            .cancellable(id: 1)
        )
      case .b1:
        return
          EffectTask
          .concatenate(.init(value: .b2), .init(value: .b3))
      case .c1:
        return
          EffectTask
          .concatenate(.init(value: .c2), .init(value: .c3))
      case .b2, .b3, .c2, .c3:
        return .none

      case .d:
        return .cancel(id: 1)
      }
    }

    let store = TestStore(
      initialState: State(),
      reducer: reducer
    )

    await store.send(.a)

    await mainQueue.advance(by: 1)

    await store.receive(.b1)
    await store.receive(.b2)
    await store.receive(.b3)

    await store.receive(.c1)
    await store.receive(.c2)
    await store.receive(.c3)

    await store.send(.d)
  }

  func testAsync() async {
    enum Action: Equatable {
      case tap
      case response(Int)
    }
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action> { state, action in
        switch action {
        case .tap:
          return .task { .response(42) }
        case let .response(number):
          state = number
          return .none
        }
      }
    )

    await store.send(.tap)
    await store.receive(.response(42)) {
      $0 = 42
    }
  }

  #if DEBUG
    func testExpectedStateEquality() async {
      struct State: Equatable {
        var count: Int = 0
        var isChanging: Bool = false
      }

      enum Action: Equatable {
        case increment
        case changed(from: Int, to: Int)
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .increment:
          state.isChanging = true
          return EffectTask(value: .changed(from: state.count, to: state.count + 1))
        case .changed(let from, let to):
          state.isChanging = false
          if state.count == from {
            state.count = to
          }
          return .none
        }
      }

      let store = TestStore(initialState: State(), reducer: reducer)

      await store.send(.increment) {
        $0.isChanging = true
      }
      await store.receive(.changed(from: 0, to: 1)) {
        $0.isChanging = false
        $0.count = 1
      }

      XCTExpectFailure {
        _ = store.send(.increment) {
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

    func testExpectedStateEqualityMustModify() async {
      struct State: Equatable {
        var count: Int = 0
      }

      enum Action: Equatable {
        case noop, finished
      }

      let reducer = Reduce<State, Action> { state, action in
        switch action {
        case .noop:
          return EffectTask(value: .finished)
        case .finished:
          return .none
        }
      }

      let store = TestStore(initialState: State(), reducer: reducer)

      await store.send(.noop)
      await store.receive(.finished)

      XCTExpectFailure {
        _ = store.send(.noop) {
          $0.count = 0
        }
      }
      XCTExpectFailure {
        store.receive(.finished) {
          $0.count = 0
        }
      }
    }
  #endif

  func testStateAccess() async {
    enum Action { case a, b, c, d }
    let store = TestStore(
      initialState: 0,
      reducer: Reduce<Int, Action> { count, action in
        switch action {
        case .a:
          count += 1
          return .merge(.init(value: .b), .init(value: .c), .init(value: .d))
        case .b, .c, .d:
          count += 1
          return .none
        }
      }
    )

    await store.send(.a) {
      $0 = 1
      XCTAssertEqual(store.state, 0)
    }
    XCTAssertEqual(store.state, 1)
    await store.receive(.b) {
      $0 = 2
      XCTAssertEqual(store.state, 1)
    }
    XCTAssertEqual(store.state, 2)
    await store.receive(.c) {
      $0 = 3
      XCTAssertEqual(store.state, 2)
    }
    XCTAssertEqual(store.state, 3)
    await store.receive(.d) {
      $0 = 4
      XCTAssertEqual(store.state, 3)
    }
    XCTAssertEqual(store.state, 4)
  }

  func testOverrideDependenciesDirectlyOnReducer() {
    struct Counter: ReducerProtocol {
      @Dependency(\.calendar) var calendar
      @Dependency(\.locale) var locale
      @Dependency(\.timeZone) var timeZone
      @Dependency(\.urlSession) var urlSession

      func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: Counter()
        .dependency(\.calendar, Calendar(identifier: .gregorian))
        .dependency(\.locale, Locale(identifier: "en_US"))
        .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .dependency(\.urlSession, URLSession(configuration: .ephemeral))
    )

    store.send(true) { $0 = 1 }
  }

  func testOverrideDependenciesOnTestStore() {
    struct Counter: ReducerProtocol {
      @Dependency(\.calendar) var calendar
      @Dependency(\.locale) var locale
      @Dependency(\.timeZone) var timeZone
      @Dependency(\.urlSession) var urlSession

      func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }

    let store = TestStore(
      initialState: 0,
      reducer: Counter()
    )
    store.dependencies.calendar = Calendar(identifier: .gregorian)
    store.dependencies.locale = Locale(identifier: "en_US")
    store.dependencies.timeZone = TimeZone(secondsFromGMT: 0)!
    store.dependencies.urlSession = URLSession(configuration: .ephemeral)

    store.send(true) { $0 = 1 }
  }
}
