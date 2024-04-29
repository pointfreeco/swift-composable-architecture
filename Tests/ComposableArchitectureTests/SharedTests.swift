import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class SharedTests: XCTestCase {
  @MainActor
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

  @MainActor
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
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount = 2
    }
    XCTAssertEqual(store.state.sharedCount, 1)
  }

  @MainActor
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

    XCTExpectFailure {
      $0.compactDescription == """
        A state change does not match expectation: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 3,
            +   _sharedCount: #1 2,
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount = 3
    }
    XCTAssertEqual(store.state.sharedCount, 2)
  }

  @MainActor
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

  @MainActor
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

  @MainActor
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
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount += 2
    }
  }

  @MainActor
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

  @MainActor
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
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.request)
    await store.receive(\.sharedIncrement)
  }

  @MainActor
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
    await store.send(.longLivingEffect).finish()
    store.assert {
      $0.sharedCount = 1
    }
  }

  @MainActor
  func testMutationOfSharedStateInLongLivingEffect_NoAssertion() async {
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
        Test store completed before asserting against changes to shared state: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 0,
            +   _sharedCount: #1 1,
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)

        Invoke "TestStore.assert" at the end of this test to assert against changes to shared state.
        """
    }
    await store.send(.longLivingEffect)
  }

  @MainActor
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
        A state change does not match expectation: …

              SharedFeature.State(
                _count: 0,
                _profile: #1 Profile(…),
            −   _sharedCount: #1 2,
            +   _sharedCount: #1 1,
                _stats: #1 Stats(count: 0),
                _isOn: #1 false
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.longLivingEffect)
    store.assert {
      $0.sharedCount = 2
    }
  }

  @MainActor
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

  @MainActor
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
    store.assert {
      $0.count = 42
    }
  }

  @MainActor
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

  @MainActor
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

  func testObservation_projected() {
    @Shared var count: Int
    _count = Shared(0)
    let countDidChange = self.expectation(description: "countDidChange")
    withPerceptionTracking {
      _ = $count
    } onChange: {
      countDidChange.fulfill()
    }
    $count = Shared(1)
    self.wait(for: [countDidChange], timeout: 0)
  }

  @available(*, deprecated)
  @MainActor
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

  @MainActor
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

  @MainActor
  func testPublisher() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let sharedCount = Shared(0)
    var counts = [Int]()
    sharedCount.publisher.sink { _ in
    } receiveValue: { count in
      XCTAssertEqual(sharedCount.wrappedValue, count - 1)
      counts.append(count)
    }
    .store(in: &cancellables)

    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1])
    sharedCount.wrappedValue += 1
    XCTAssertEqual(counts, [1, 2])
  }

  @MainActor
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

  @MainActor
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

  @MainActor
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
    // TODO: Should we runtime warn on re-entrant mutations?
    XCTAssertEqual(count, 1)
    XCTAssertEqual(userDefaults.integer(forKey: "count"), 1)
  }

  @MainActor
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

  @MainActor
  func testMultiplePublisherSubscriptions() async {
    let runCount = 10
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

  @MainActor
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

  @MainActor
  func testObserveWithPrintChanges() async {
    let store = TestStore(initialState: SimpleFeature.State(count: Shared(0))) {
      SimpleFeature()._printChanges()
    }

    var observations: [Int] = []
    observe {
      observations.append(store.state.count)
    }

    XCTAssertEqual(observations, [0])
    await store.send(.incrementInReducer) {
      dump($0.$count)
      $0.count += 1
    }
    XCTAssertEqual(observations, [0, 1])
  }

  func testSharedDefaults_UseDefault() {
    @Shared(.isOn) var isOn
    XCTAssertEqual(isOn, false)
  }

  func testSharedDefaults_OverrideDefault() {
    @Shared(.isOn) var isOn = true
    XCTAssertEqual(isOn, true)
  }

  func testSharedDefaults_MultipleWithDifferentDefaults() async throws {
    @Shared(.isOn) var isOn1
    @Shared(.isOn) var isOn2 = true
    @Shared(.appStorage("isOn")) var isOn3 = true

    XCTAssertEqual(isOn1, false)
    XCTAssertEqual(isOn2, false)
    XCTAssertEqual(isOn3, false)

    isOn2 = true
    XCTAssertEqual(isOn1, true)
    XCTAssertEqual(isOn2, true)
    XCTAssertEqual(isOn3, true)

    isOn1 = false
    XCTAssertEqual(isOn1, false)
    XCTAssertEqual(isOn2, false)
    XCTAssertEqual(isOn3, false)

    isOn3 = true
    XCTAssertEqual(isOn1, true)
    XCTAssertEqual(isOn2, true)
    XCTAssertEqual(isOn3, true)
  }

  func testSharedReaderDefaults_MultipleWithDifferentDefaults() async throws {
    @Shared(.appStorage("isOn")) var isOn = false
    @SharedReader(.isOn) var isOn1
    @SharedReader(.isOn) var isOn2 = true
    @SharedReader(.appStorage("isOn")) var isOn3 = true

    XCTAssertEqual(isOn1, false)
    XCTAssertEqual(isOn2, false)
    XCTAssertEqual(isOn3, false)

    isOn = true
    XCTAssertEqual(isOn1, true)
    XCTAssertEqual(isOn2, true)
    XCTAssertEqual(isOn3, true)
  }

  @MainActor
  func testPrivateSharedState() async {
    let isOn = Shared(false)
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats()),
        isOn: isOn
      )
    ) {
      SharedFeature()
    }

    await store.send(.toggleIsOn) {
      _ = $0
      isOn.wrappedValue = true
    }
    await store.send(.toggleIsOn) {
      _ = $0
      isOn.wrappedValue = false
    }
  }

  func testEquatability_DifferentReference() {
    let count = Shared(0)
    @Shared(.appStorage("count")) var appStorageCount = 0
    @Shared(
      .fileStorage(
        URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent("count.json")
      )
    )
    var fileStorageCount = 0
    @Shared(.inMemory("count")) var inMemoryCount = 0

    XCTAssertEqual(count, $appStorageCount)
    XCTAssertEqual($appStorageCount, $fileStorageCount)
    XCTAssertEqual($fileStorageCount, $inMemoryCount)
    XCTAssertEqual($inMemoryCount, count)
  }

  func testEquatable_DifferentKeyPath() {
    struct Settings {
      var isOn = false
      var hasSeen = false
    }
    @Shared(.inMemory("settings")) var settings = Settings()
    XCTAssertEqual($settings.isOn, $settings.hasSeen)
    withSharedChangeTracking { tracker in
      settings.isOn.toggle()
      XCTAssertNotEqual(settings.isOn, settings.hasSeen)
      XCTAssertNotEqual($settings.isOn, $settings.hasSeen)
      XCTAssertNotEqual($settings.hasSeen, $settings.isOn)
      tracker.assert {
        XCTAssertEqual(settings.isOn, settings.hasSeen)
        XCTAssertEqual($settings.isOn, $settings.hasSeen)
        XCTAssertEqual($settings.hasSeen, $settings.isOn)
        settings.hasSeen.toggle()
        XCTAssertNotEqual(settings.isOn, settings.hasSeen)
        XCTAssertNotEqual($settings.isOn, $settings.hasSeen)
        XCTAssertNotEqual($settings.hasSeen, $settings.isOn)
      }
    }
  }

  func testSelfEqualityInAnAssertion() {
    let count = Shared(0)
    withSharedChangeTracking { tracker in
      count.wrappedValue += 1
      tracker.assert {
        XCTAssertNotEqual(count, count)
        XCTAssertEqual(count.wrappedValue, count.wrappedValue)
      }
      XCTAssertEqual(count, count)
      XCTAssertEqual(count.wrappedValue, count.wrappedValue)
    }
    XCTAssertEqual(count, count)
    XCTAssertEqual(count.wrappedValue, count.wrappedValue)
  }

  func testBasicAssertion() {
    let count = Shared(0)
    withSharedChangeTracking { tracker in
      count.wrappedValue += 1
      tracker.assert {
        count.wrappedValue += 1
        XCTAssertEqual(count, count)
        XCTAssertEqual(count.wrappedValue, count.wrappedValue)
      }
      XCTAssertEqual(count, count)
      XCTAssertEqual(count.wrappedValue, count.wrappedValue)
    }
    XCTAssertEqual(count, count)
    XCTAssertEqual(count.wrappedValue, count.wrappedValue)
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
    @Shared fileprivate var isOn: Bool
    init(
      count: Int = 0,
      profile: Shared<Profile>,
      sharedCount: Shared<Int>,
      stats: Shared<Stats>,
      isOn: Shared<Bool> = Shared(false)
    ) {
      self.count = count
      self._profile = profile
      self._sharedCount = sharedCount
      self._stats = stats
      self._isOn = isOn
    }
  }
  enum Action {
    case increment
    case incrementStats
    case longLivingEffect
    case noop
    case request
    case sharedIncrement
    case toggleIsOn
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
      case .request:
        return .run { send in
          await send(.sharedIncrement)
        }
      case .sharedIncrement:
        state.sharedCount += 1
        return .none
      case .toggleIsOn:
        state.isOn.toggle()
        return .none
      }
    }
  }
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

extension PersistenceReaderKey where Self == PersistenceKeyDefault<AppStorageKey<Bool>> {
  static var isOn: Self {
    PersistenceKeyDefault(.appStorage("isOn"), false)
  }
}

// NB: This is a compile-time test to verify that optional shared state with defaults compiles.
struct StateWithOptionalSharedAndDefault {
  @Shared(.optionalValueWithDefault) var optionalValueWithDefault
}
extension PersistenceKey where Self == PersistenceKeyDefault<AppStorageKey<Bool?>> {
  fileprivate static var optionalValueWithDefault: Self {
    return PersistenceKeyDefault(.appStorage("optionalValueWithDefault"), nil)
  }
}
