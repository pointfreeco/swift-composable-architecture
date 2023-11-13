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
            .run { send in
              try await mainQueue.sleep(for: .seconds(1))
              await send(.b1)
              await send(.c1)
            },
            .run { _ in try await Task.never() }
              .cancellable(id: 1)
          )
        case .b1:
          return .concatenate(.send(.b2), .send(.b3))
        case .c1:
          return .concatenate(.send(.c2), .send(.c3))
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
          return .run { send in await send(.response(42)) }
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
          case let .changed(from, to):
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

      XCTExpectFailure()
      await store.send(.increment) {
        $0.isChanging = false
      }

      XCTExpectFailure()
      await store.receive(.changed(from: 1, to: 2)) {
        $0.isChanging = true
        $0.count = 1100
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

      XCTExpectFailure()
      await store.send(.noop) {
        $0.count = 0
      }

      XCTExpectFailure()
      await store.receive(.finished) {
        $0.count = 0
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

      await store.send(.noop)
      XCTExpectFailure()
      await store.receive(.noop)

      await store.send(.noop)
      XCTExpectFailure()
      await store.receive { $0 == .noop }
    }
  #endif

  func testStateAccess() async {
    enum Action { case a, b, c, d }
    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { count, action in
        switch action {
        case .a:
          count += 1
          return .merge(.send(.b), .send(.c), .send(.d))
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

  @Reducer
  struct Feature_testOverrideDependenciesDirectlyOnReducer {
    @Dependency(\.calendar) var calendar
    @Dependency(\.locale) var locale
    @Dependency(\.timeZone) var timeZone
    @Dependency(\.urlSession) var urlSession

    var body: some Reducer<Int, Bool> {
      Reduce { state, action in
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }
  }
  func testOverrideDependenciesDirectlyOnReducer() async {
    let store = TestStore(initialState: 0) {
      Feature_testOverrideDependenciesDirectlyOnReducer()
        .dependency(\.calendar, Calendar(identifier: .gregorian))
        .dependency(\.locale, Locale(identifier: "en_US"))
        .dependency(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .dependency(\.urlSession, URLSession(configuration: .ephemeral))
    }

    await store.send(true) { $0 = 1 }
  }

  @Reducer
  struct Feature_testOverrideDependenciesOnTestStore {
    @Dependency(\.calendar) var calendar
    @Dependency(\.locale) var locale
    @Dependency(\.timeZone) var timeZone
    @Dependency(\.urlSession) var urlSession

    var body: some Reducer<Int, Bool> {
      Reduce { state, action in
        _ = self.calendar
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }
  }
  func testOverrideDependenciesOnTestStore() async {
    let store = TestStore(initialState: 0) {
      Feature_testOverrideDependenciesOnTestStore()
    }
    store.dependencies.calendar = Calendar(identifier: .gregorian)
    store.dependencies.locale = Locale(identifier: "en_US")
    store.dependencies.timeZone = TimeZone(secondsFromGMT: 0)!
    store.dependencies.urlSession = URLSession(configuration: .ephemeral)

    await store.send(true) { $0 = 1 }
  }

  @Reducer
  struct Feature_testOverrideDependenciesOnTestStore_MidwayChange {
    @Dependency(\.date.now) var now

    var body: some Reducer<Int, Void> {
      Reduce { state, _ in
        state = Int(self.now.timeIntervalSince1970)
        return .none
      }
    }
  }
  func testOverrideDependenciesOnTestStore_MidwayChange() async {
    let store = TestStore(initialState: 0) {
      Feature_testOverrideDependenciesOnTestStore_MidwayChange()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    }

    await store.send(()) { $0 = 1_234_567_890 }

    store.dependencies.date.now = Date(timeIntervalSince1970: 987_654_321)

    await store.send(()) { $0 = 987_654_321 }
  }

  @Reducer
  struct Feature_testOverrideDependenciesOnTestStore_Init {
    @Dependency(\.calendar) var calendar
    @Dependency(\.client.fetch) var fetch
    @Dependency(\.locale) var locale
    @Dependency(\.timeZone) var timeZone
    @Dependency(\.urlSession) var urlSession

    var body: some Reducer<Int, Bool> {
      Reduce { state, action in
        _ = self.calendar
        _ = self.fetch()
        _ = self.locale
        _ = self.timeZone
        _ = self.urlSession
        state += action ? 1 : -1
        return .none
      }
    }
  }
  func testOverrideDependenciesOnTestStore_Init() async {
    let store = TestStore(initialState: 0) {
      Feature_testOverrideDependenciesOnTestStore_Init()
    } withDependencies: {
      $0.calendar = Calendar(identifier: .gregorian)
      $0.client.fetch = { 1 }
      $0.locale = Locale(identifier: "en_US")
      $0.timeZone = TimeZone(secondsFromGMT: 0)!
      $0.urlSession = URLSession(configuration: .ephemeral)
    }

    await store.send(true) { $0 = 1 }
  }

  @Reducer
  struct Feature_testDependenciesEarlyBinding {
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
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .tap:
          state.count += 1
          return .run { send in await send(.response(42)) }
        case let .response(number):
          state.count = number
          state.date = now
          return .none
        }
      }
    }
  }
  func testDependenciesEarlyBinding() async {
    let store = TestStore(initialState: Feature_testDependenciesEarlyBinding.State()) {
      Feature_testDependenciesEarlyBinding()
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

  func testSubscribeReceiveCombineScheduler() async {
    let subject = PassthroughSubject<Void, Never>()
    let scheduler = DispatchQueue.test

    struct State: Equatable {
      var count: Int = 0
    }

    enum Action: Equatable {
      case increment
      case start
    }

    let store = TestStore(initialState: State()) {
      Reduce<State, Action> { state, action in
        switch action {
        case .start:
          return .publisher {
            subject
              .subscribe(on: scheduler)
              .receive(on: scheduler)
              .map { .increment }
          }
        case .increment:
          state.count += 1
          return .none
        }
      }
    }

    let task = await store.send(.start)
    await scheduler.advance()
    subject.send()
    await scheduler.advance()
    await store.receive(.increment) { $0.count = 1 }
    await task.cancel()
  }

  func testMainSerialExecutor_AutoAssignsAndResets_False() async {
    uncheckedUseMainSerialExecutor = false
    XCTAssertFalse(uncheckedUseMainSerialExecutor)
    var store: TestStore? = TestStore(initialState: 0) {
      EmptyReducer<Int, Void>()
    }
    XCTAssertTrue(uncheckedUseMainSerialExecutor)
    store = nil
    XCTAssertFalse(uncheckedUseMainSerialExecutor)
    _ = store
  }

  func testMainSerialExecutor_AutoAssignsAndResets_True() async {
    uncheckedUseMainSerialExecutor = true
    XCTAssertTrue(uncheckedUseMainSerialExecutor)
    var store: TestStore? = TestStore(initialState: 0) {
      EmptyReducer<Int, Void>()
    }
    XCTAssertTrue(uncheckedUseMainSerialExecutor)
    store = nil
    XCTAssertTrue(uncheckedUseMainSerialExecutor)
    _ = store
  }
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
