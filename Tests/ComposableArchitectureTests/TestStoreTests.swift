import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class TestStoreTests: BaseTCATestCase {
  func testEffectConcatenation() async {
    struct State: Equatable {}

    enum Action: Equatable {
      case a, b1, b2, b3, c1, c2, c3, d
    }

    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { _, action in
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
    }

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
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .tap:
          return .task { .response(42) }
        case let .response(number):
          state = number
          return .none
        }
      }
    }

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

      let store = TestStore(initialState: State()) {
        Reduce<State, Action> { state, action in
          switch action {
          case .increment:
            state.isChanging = true
            return .send(.changed(from: state.count, to: state.count + 1))
          case .changed(let from, let to):
            state.isChanging = false
            if state.count == from {
              state.count = to
            }
            return .none
          }
        }
      }

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

      let store = TestStore(initialState: State()) {
        Reduce<State, Action> { state, action in
          switch action {
          case .noop:
            return .send(.finished)
          case .finished:
            return .none
          }
        }
      }

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

    func testReceiveActionMatchingPredicate() async {
      enum Action: Equatable {
        case noop, finished
      }

      let store = TestStore(initialState: 0) {
        Reduce<Int, Action> { state, action in
          switch action {
          case .noop:
            return .send(.finished)
          case .finished:
            return .none
          }
        }
      }

      let predicateShouldBeCalledExpectation = expectation(
        description: "predicate should be called")
      await store.send(.noop)
      await store.receive { action in
        predicateShouldBeCalledExpectation.fulfill()
        return action == .finished
      }
      _ = { wait(for: [predicateShouldBeCalledExpectation], timeout: 0) }()

      XCTExpectFailure {
        store.send(.noop)
        store.receive(.noop)
      }

      XCTExpectFailure {
        store.send(.noop)
        store.receive { $0 == .noop }
      }
    }
  #endif

  func testStateAccess() async {
    enum Action { case a, b, c, d }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { count, action in
        switch action {
        case .a:
          count += 1
          return .merge(.init(value: .b), .init(value: .c), .init(value: .d))
        case .b, .c, .d:
          count += 1
          return .none
        }
      }
    }

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

    let store = TestStore(initialState: 0) {
      Counter()
        .dependency(\.calendar, Calendar(identifier: .gregorian))
        .dependency(\.locale, Locale(identifier: "en_US"))
        .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .dependency(\.urlSession, URLSession(configuration: .ephemeral))
    }

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

    let store = TestStore(initialState: 0) {
      Counter()
    }
    store.dependencies.calendar = Calendar(identifier: .gregorian)
    store.dependencies.locale = Locale(identifier: "en_US")
    store.dependencies.timeZone = TimeZone(secondsFromGMT: 0)!
    store.dependencies.urlSession = URLSession(configuration: .ephemeral)

    store.send(true) { $0 = 1 }
  }

  func testOverrideDependenciesOnTestStore_MidwayChange() {
    struct Counter: ReducerProtocol {
      @Dependency(\.date.now) var now

      func reduce(into state: inout Int, action: ()) -> EffectTask<Void> {
        state = Int(self.now.timeIntervalSince1970)
        return .none
      }
    }

    let store = TestStore(initialState: 0) {
      Counter()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    }

    store.send(()) { $0 = 1_234_567_890 }

    store.dependencies.date.now = Date(timeIntervalSince1970: 987_654_321)

    store.send(()) { $0 = 987_654_321 }
  }

  func testOverrideDependenciesOnTestStore_Init() {
    struct Counter: ReducerProtocol {
      @Dependency(\.calendar) var calendar
      @Dependency(\.client.fetch) var fetch
      @Dependency(\.locale) var locale
      @Dependency(\.timeZone) var timeZone
      @Dependency(\.urlSession) var urlSession

      func reduce(into state: inout Int, action: Bool) -> EffectTask<Bool> {
        _ = self.calendar
        _ = self.fetch()
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }

    let store = TestStore(initialState: 0) {
      Counter()
    } withDependencies: {
      $0.calendar = Calendar(identifier: .gregorian)
      $0.client.fetch = { 1 }
      $0.locale = Locale(identifier: "en_US")
      $0.timeZone = TimeZone(secondsFromGMT: 0)!
      $0.urlSession = URLSession(configuration: .ephemeral)
    }

    store.send(true) { $0 = 1 }
  }

  func testDependenciesEarlyBinding() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var count = 0
        var date: Date
        init() {
          @Dependency(\.date.now) var now: Date
          self.date = now
        }
      }
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date.now) var now: Date
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .tap:
          state.count += 1
          return .task { .response(42) }
        case let .response(number):
          state.count = number
          state.date = now
          return .none
        }
      }
    }

    let store = TestStore(initialState: Feature.State()) {
      Feature()
    } withDependencies: {
      $0.date = .constant(Date(timeIntervalSince1970: 1_234_567_890))
    }

    await store.send(.tap) {
      @Dependency(\.date.now) var now: Date
      $0.count = 1
      $0.date = now
    }
    await store.receive(.response(42)) {
      @Dependency(\.date.now) var now: Date
      $0.count = 42
      $0.date = now
    }
  }

  func testPrepareDependenciesCalledOnce() {
    var count = 0
    let store = TestStore(initialState: 0) {
      EmptyReducer<Int, Void>()
    } withDependencies: { _ in
      count += 1
    }

    XCTAssertEqual(count, 1)
    _ = store
  }

  func testEffectEmitAfterSkipInFlightEffects() async {
    let mainQueue = DispatchQueue.test
    enum Action: Equatable { case tap, response }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .tap:
          return .run { send in
            try await mainQueue.sleep(for: .seconds(1))
            await send(.response)
          }
        case .response:
          state = 42
          return .none
        }
      }
    }

    await store.send(.tap)
    await store.skipInFlightEffects()
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.response) {
      $0 = 42
    }
  }

  func testAssert_NonExhaustiveTestStore() async {
    let store = TestStore(initialState: 0) {
      EmptyReducer<Int, Void>()
    }
    store.exhaustivity = .off

    store.assert {
      $0 = 0
    }
  }

  #if DEBUG
    func testAssert_NonExhaustiveTestStore_Failure() async {
      let store = TestStore(initialState: 0) {
        EmptyReducer<Int, Void>()
      }
      store.exhaustivity = .off

      XCTExpectFailure {
        store.assert {
          $0 = 1
        }
      } issueMatcher: {
        $0.compactDescription == """
          A state change does not match expectation: …

              − 1
              + 0

          (Expected: −, Actual: +)
          """
      }
    }
  #endif
}

private struct Client: DependencyKey {
  var fetch: () -> Int
  static let liveValue = Client(fetch: { 42 })
}
extension DependencyValues {
  fileprivate var client: Client {
    get { self[Client.self] }
    set { self[Client.self] = newValue }
  }
}
