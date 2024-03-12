import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class SharedTests: XCTestCase {
  func testSharing() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount = 1
    }
    await store.send(.incrementStats) {
      $0.profile.stats.count = 1
      $0.stats.count = 1
    }
    XCTAssertEqual(store.state.profile.stats.count, 1)
  }

  func testSharing_Failure() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    XCTExpectFailure {
      $0.compactDescription == """
        A state change does not match expectation: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 2,
            +   _sharedCount: #1 1,
                _stats: #1 Stats(count: 0)
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount = 2
    }
    XCTAssertEqual(store.state.sharedCount, 1)
  }

  func testSharing_NonExhaustive() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    store.exhaustivity = .off(showSkippedAssertions: true)

    await store.send(.sharedIncrement)
    XCTAssertEqual(store.state.sharedCount, 1)
  }

  func testMultiSharing() async {
    @Shared(Stats()) var stats

    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: $stats)),
        sharedCount: Shared(0),
        stats: $stats
      )
    ) {
      SharedFeature()
    }
    await store.send(.incrementStats) {
      $0.profile.stats.count = 2
      $0.stats.count = 2
    }
    XCTAssertEqual(stats.count, 2)
  }

  func testIncrementalMutation() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount += 1
    }
  }

  func testIncrementalMutation_Failure() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    XCTExpectFailure {
      $0.compactDescription == """
        A state change does not match expectation: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 2,
            +   _sharedCount: #1 1,
                _stats: #1 Stats(count: 0)
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount += 2
    }
  }

  func testEffect() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    await store.send(.request)
    await store.receive(\.sharedIncrement) {
      $0.sharedCount = 1
    }
  }

  func testEffect_Failure() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    XCTExpectFailure {
      $0.compactDescription == """
        State was not expected to change, but a change occurred: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 0,
            +   _sharedCount: #1 1,
                _stats: #1 Stats(count: 0)
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.request)
    await store.receive(\.sharedIncrement)
  }

  func testMutationOfSharedStateInLongLivingEffect() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
    await store.send(.longLivingEffect)
    store.state.$sharedCount.assert {
      $0 = 1
    }
  }

  func testMutationOfSharedStateInLongLivingEffect_NoAssertion() async {
    let sharedCountInitLine = #line + 4
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
    XCTExpectFailure {
      $0.compactDescription == """
        Tracked changes to \
        'Shared<Int>@ComposableArchitectureTests/SharedTests.swift:\(sharedCountInitLine)' \
        but failed to assert: …

          − 0
          + 1

        (Before: −, After: +)

        Call 'Shared<Int>.assert' to exhaustively test these changes, or call 'skipChanges' to \
        ignore them.
        """
    }
    await store.send(.longLivingEffect)
  }

  func testMutationOfSharedStateInLongLivingEffect_IncorrectAssertion() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    } withDependencies: {
      $0.mainQueue = .immediate
    }
    XCTExpectFailure {
      $0.compactDescription == """
        XCTAssertNoDifference failed: …

          − 1
          + 2

        (First: −, Second: +)
        """
    }
    await store.send(.longLivingEffect)
    store.state.$sharedCount.assert {
      $0 = 2
    }
  }

  func testComplexSharedEffect_ReducerMutation() async {
    struct Feature: Reducer {
      struct State: Equatable {
        @Shared var count: Int
      }
      enum Action {
        case startTimer
        case stopTimer
        case timerTick
      }
      @Dependency(\.mainQueue) var queue
      enum CancelID { case timer }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .startTimer:
            return .run { send in
              for await _ in self.queue.timer(interval: .seconds(1)) {
                await send(.timerTick)
              }
            }
            .cancellable(id: CancelID.timer)
          case .stopTimer:
            return .cancel(id: CancelID.timer)
          case .timerTick:
            state.count += 1
            return .none
          }
        }
      }
    }
    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: Feature.State(count: Shared(0))) {
      Feature()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }
    await store.send(.startTimer)
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.timerTick) {
      $0.count = 1
    }
    await store.send(.stopTimer)
    await mainQueue.advance(by: .seconds(1))
  }

  func testComplexSharedEffect_EffectMutation() async {
    struct Feature: Reducer {
      struct State: Equatable {
        @Shared var count: Int
      }
      enum Action {
        case startTimer
        case stopTimer
        case timerTick
      }
      @Dependency(\.mainQueue) var queue
      enum CancelID { case timer }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .startTimer:
            return .run { [count = state.$count] send in
              for await _ in self.queue.timer(interval: .seconds(1)) {
                count.wrappedValue += 1
                await send(.timerTick)
              }
            }
            .cancellable(id: CancelID.timer)
          case .stopTimer:
            return .merge(
              .cancel(id: CancelID.timer),
              .run { [count = state.$count] _ in
                Task {
                  try await self.queue.sleep(for: .seconds(1))
                  count.wrappedValue = 42
                }
              }
            )
          case .timerTick:
            return .none
          }
        }
      }
    }
    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: Feature.State(count: Shared(0))) {
      Feature()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }
    await store.send(.startTimer)
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.timerTick) {
      $0.count = 1
    }
    await store.send(.stopTimer)
    await mainQueue.advance(by: .seconds(1))
    store.state.$count.assert {
      $0 = 42
    }
  }

  func testDump() {
    @Shared(Profile(stats: Shared(Stats()))) var profile: Profile
    XCTAssertEqual(
      String(customDumping: profile),
      """
      Profile(
        _stats: #1 Stats(count: 0)
      )
      """
    )

    let count = $profile.stats.count
    XCTAssertEqual(
      String(customDumping: count),
      """
      #1 0
      """
    )
  }

  func testSimpleFeatureFailure() async {
    let store = TestStore(initialState: SimpleFeature.State(count: Shared(0))) {
      SimpleFeature()
    }

    XCTExpectFailure {
      $0.compactDescription == """
        State was not expected to change, but a change occurred: …

              SimpleFeature.State(
            −   _count: #1 0
            +   _count: #1 1
              )

        (Expected: −, Actual: +)
        """
    }

    await store.send(.incrementInReducer)
  }

  func testObservation() {
    @Shared var count: Int
    _count = Shared(0)
    let countDidChange = self.expectation(description: "countDidChange")
    withPerceptionTracking {
      _ = count
    } onChange: {
      countDidChange.fulfill()
    }
    count += 1
    self.wait(for: [countDidChange], timeout: 0)
  }

  @available(*, deprecated)
  func testObservation_Object() {
    @Shared var object: SharedObject
    _object = Shared(SharedObject())
    let countDidChange = self.expectation(description: "countDidChange")
    withPerceptionTracking {
      _ = object.count
    } onChange: {
      countDidChange.fulfill()
    }
    object.count += 1
    self.wait(for: [countDidChange], timeout: 0)
  }

  func testAssertSharedStateWithNoChanges() {
    let store = TestStore(initialState: SimpleFeature.State(count: Shared(0))) {
      SimpleFeature()
    }
    XCTExpectFailure {
      $0.compactDescription == """
        Expected changes, but none occurred.
        """
    }
    store.state.$count.assert {
      $0 = 0
    }
  }

  func testPublisher() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let sharedCount = Shared(0)
    var counts = [Int]()
    sharedCount.publisher.sink { _ in
    } receiveValue: { count in
      counts.append(count)
    }
    .store(in: &cancellables)

    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1])
    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1, 2])
  }

  func testPublisher_MultipleSubscribers() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let sharedCount = Shared(0)
    var counts = [Int]()
    sharedCount.publisher.sink { _ in
    } receiveValue: { count in
      counts.append(count)
    }
    .store(in: &cancellables)
    sharedCount.publisher.sink { _ in
    } receiveValue: { count in
      counts.append(count)
    }
    .store(in: &cancellables)

    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1, 1])
    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1, 1, 2, 2])
  }

  func testPublisher_MutateInSink() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let sharedCount = Shared(0)
    var counts = [Int]()
    sharedCount.publisher.sink { _ in
    } receiveValue: { count in
      counts.append(count)
      if count == 1 {
        sharedCount.wrappedValue = 2
      }
    }
    .store(in: &cancellables)

    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1, 2])
  }

  func testPublisher_Persistence_MutateInSink() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    @Shared(.appStorage("count")) var count = 0
    var counts = [Int]()
    $count.publisher.sink { _ in
    } receiveValue: { newCount in
      counts.append(newCount)
      if newCount == 1 {
        count = 2
      }
    }
    .store(in: &cancellables)

    count += 1
    XCTAssertEqual(counts, [1, 2])
    @Dependency(\.defaultAppStorage) var userDefaults
    XCTAssertEqual(userDefaults.integer(forKey: "count"), 2)
  }

  func testPublisher_Persistence_ExternalChange() async throws {
    @Dependency(\.defaultAppStorage) var defaults
    @Shared(.appStorage("count")) var count = 0
    XCTAssertEqual(count, 0)

    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    var counts = [Int]()
    $count.publisher.sink { _ in
    } receiveValue: { newCount in
      counts.append(newCount)
      if newCount == 1 { count = 2 }
    }
    .store(in: &cancellables)

    try await Task.sleep(nanoseconds: 1_000_000)
    defaults.set(1, forKey: "count")
    try await Task.sleep(nanoseconds: 10_000_000)
    XCTAssertEqual(counts, [1, 2])
    XCTAssertEqual(defaults.integer(forKey: "count"), 2)
  }

  func testMultiplePublisherSubscriptions() async {
    let runCount = 1_000
    for _ in 1...runCount {
      let store = TestStore(initialState: ListFeature.State()) {
        ListFeature()
      } withDependencies: {
        $0.uuid = .incrementing
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.children(.element(id: 1, action: .onAppear)))
      await store.send(.children(.element(id: 2, action: .onAppear)))
      await store.send(.children(.element(id: 3, action: .onAppear)))
      await store.send(.incrementValue) {
        $0.value = 1
      }
      await store.receive(\.children[id:0].response) {
        $0.children[id: 0]?.text = "1"
      }
      await store.receive(\.children[id:1].response) {
        $0.children[id: 1]?.text = "1"
      }
      await store.receive(\.children[id:2].response) {
        $0.children[id: 2]?.text = "1"
      }
      await store.receive(\.children[id:3].response) {
        $0.children[id: 3]?.text = "1"
      }
    }
  }

  func testEarlySharedStateMutation() async {
    let store = TestStore(initialState: EarlySharedStateMutation.State(count: Shared(0))) {
      EarlySharedStateMutation()
    }

    XCTTODO(
      """
      This currently fails because the effect returned from '.action' synchronously sends the
      '.response' action, which then mutates the shared state. Because the TestStore processes
      actions immediately the shared state mutation must be asserted in `store.send` rather than
      store.receive.

      We should update the TestStore so that effects suspend until one does 'store.receive'. That
      would fix this test.
      """
    )
    await store.send(.action)
    await store.receive(.response) {
      $0.count = 42
    }
  }
}

@Reducer
private struct SharedFeature {
  @ObservableState
  struct State: Equatable {
    var count = 0
    @Shared var profile: Profile
    @Shared var sharedCount: Int
    @Shared var stats: Stats
  }
  enum Action {
    case increment
    case incrementStats
    case longLivingEffect
    case noop
    case sharedIncrement
    case request
  }
  @Dependency(\.mainQueue) var mainQueue
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none
      case .incrementStats:
        state.profile.stats.count += 1
        state.stats.count += 1
        return .none
      case .longLivingEffect:
        return .run { [sharedCount = state.$sharedCount] _ in
          try await self.mainQueue.sleep(for: .seconds(1))
          sharedCount.wrappedValue += 1
        }
      case .noop:
        return .none
      case .sharedIncrement:
        state.sharedCount += 1
        return .none
      case .request:
        return .run { send in
          await send(.sharedIncrement)
        }
      }
    }
  }

  // TODO: Show that we expect Send should suspend to avoid processing shared mutations
  // TODO: Show that we expect TestStore.receive to receive incremental updates
  // TODO: Show that you get failure if you do `store.$shared.assert` when there's nothing to assert on
}

private struct Stats: Codable, Equatable {
  var count = 0
}
private struct Profile: Equatable {
  @Shared var stats: Stats
}
@Reducer
private struct SimpleFeature {
  struct State: Equatable {
    @Shared var count: Int
  }
  enum Action {
    case incrementInEffect
    case incrementInReducer
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementInEffect:
        return .run { [count = state.$count] _ in
          count.wrappedValue += 1
        }
      case .incrementInReducer:
        state.count += 1
        return .none
      }
    }
  }
}

@Perceptible
class SharedObject {
  var count = 0
}

@Reducer
private struct RowFeature {
  @ObservableState
  struct State: Equatable, Identifiable {
    let id: Int
    var text: String
    @Shared var value: Int
  }

  enum Action: Equatable {
    case onAppear
    case response(Int)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .response(newValue):
        state.text = "\(newValue)"
        return .none

      case .onAppear:
        return .publisher { [publisher = state.$value.publisher] in
          publisher
            .map(Action.response)
            .prefix(1)
        }
      }
    }
  }
}

@Reducer
private struct ListFeature {
  @ObservableState
  struct State: Equatable {
    @Shared var value: Int
    var children: IdentifiedArrayOf<RowFeature.State>

    init(value: Int = 0) {
      @Dependency(\.uuid) var uuid
      self._value = Shared(value)
      self.children = [
        .init(id: 0, text: "0", value: _value),
        .init(id: 1, text: "0", value: _value),
        .init(id: 2, text: "0", value: _value),
        .init(id: 3, text: "0", value: _value),
      ]
    }
  }

  enum Action: Equatable {
    case children(IdentifiedActionOf<RowFeature>)
    case incrementValue
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .children:
        return .none

      case .incrementValue:
        state.value += 1
        return .none
      }
    }
    .forEach(\.children, action: \.children) { RowFeature() }
  }
}

@Reducer
private struct EarlySharedStateMutation {
  @ObservableState
  struct State: Equatable {
    @Shared var count: Int
  }
  enum Action {
    case action
    case response
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .action:
        return .send(.response)
      case .response:
        state.count = 42
        return .none
      }
    }
  }
}
