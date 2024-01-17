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
    await store.send(.noop)
    await store.send(.increment) {
      $0.count = 1
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
              _profile: Profile(…),
          −   _sharedCount: 2,
          +   _sharedCount: 1,
              _stats: Stats(count: 0),
              _statsDependency: Stats(count: 0)
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
                _profile: Profile(…),
            −   _sharedCount: 2,
            +   _sharedCount: 1,
                _stats: Stats(count: 0),
                _statsDependency: Stats(count: 0)
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
                _profile: Profile(…),
            −   _sharedCount: 0,
            +   _sharedCount: 1,
                _stats: Stats(count: 0),
                _statsDependency: Stats(count: 0)
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.request)
    await store.receive(\.sharedIncrement)
  }

  func testDependency() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    }
    await store.send(.sharedDependencyIncrement) {
      $0.statsDependency.count = 1
    }
  }

  func testDependency_Failure() async {
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
                _profile: Profile(…),
                _sharedCount: 0,
                _stats: Stats(count: 0),
            −   _statsDependency: Stats(count: 2)
            +   _statsDependency: Stats(count: 1)
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.sharedDependencyIncrement) {
      $0.statsDependency.count = 2
    }
  }

  func testDependency_WithOverride() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    } withDependencies: {
      $0[Shared<Stats>.self] = Shared(Stats(count: 42))
    }
    await store.send(.sharedDependencyIncrement) {
      $0.statsDependency.count = 43
    }
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
        Tracked changes to 'Shared<Int>@ComposableArchitectureTests/SharedTests.swift:\(sharedCountInitLine)' but failed to assert: …

          − 0
          + 1

        (Before: −, After: +)

        Call 'Shared<Int>.assert' to exhaustively test these changes, or call 'skipChanges' to ignore them.
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

  func testComplexSharedDependencyEffect_EffectMutation() async {
    struct Feature: Reducer {
      struct State: Equatable {
        @SharedDependency var stats: Stats
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
                @SharedDependency var stats: Stats
                stats.count += 1
                await send(.timerTick)
              }
            }
            .cancellable(id: CancelID.timer)
          case .stopTimer:
            return .merge(
              .cancel(id: CancelID.timer),
              .run { _ in
                Task {
                  try await self.queue.sleep(for: .seconds(1))
                  @SharedDependency var stats: Stats
                  stats.count = 42
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
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }
    await store.send(.startTimer)
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.timerTick) {
      $0.stats.count = 3
    }
    await store.send(.stopTimer)
    await mainQueue.advance(by: .seconds(1))
    store.state.$stats.assert {
      $0.count = 42
    }
  }

  func testSharedDependencyAccessWithOnlyTestValue_TestContext() {
    @SharedDependency var shared: SharedStateWithTestValue
    _ = shared
  }

  func testSharedDependencyAccessWithOnlyTestValue_LiveContext() {
    XCTExpectFailure {
      withDependencies {
        $0.context = .live
      } operation: {
        @SharedDependency var shared: SharedStateWithTestValue
        _ = shared
      }
    } issueMatcher: {
      $0.compactDescription == """
        "@Dependency(Shared<ComposableArchitectureTests.SharedStateWithTestValue>.self)" has no live implementation, but was accessed from a live context.

          Location:
            ComposableArchitectureTests/SharedTests.swift:499
          Dependency:
            Shared<ComposableArchitectureTests.SharedStateWithTestValue>

        Every dependency registered with the library must conform to "DependencyKey", and that conformance must be visible to the running application.

        To fix, make sure that "Shared<ComposableArchitectureTests.SharedStateWithTestValue>" conforms to "DependencyKey" by providing a live implementation of your dependency, and make sure that the conformance is linked with this current application.
        """
    }
  }

  func testSharedDependencyAccessWithOnlyLiveValue_TestContext() {
    @SharedDependency var shared: SharedStateWithLiveValue
    _ = shared
  }

  func testSharedDependencyAccessWithOnlyLiveValue_LiveContext() {
    withDependencies {
      $0.context = .live
    } operation: {
      @SharedDependency var shared: SharedStateWithLiveValue
      _ = shared
    }
  }

  func testDump() {
    let profile = Shared(Profile(stats: Shared(Stats())))
    XCTAssertEqual(
      String(customDumping: profile),
      """
      Profile(
        _stats: Stats(count: 0)
      )
      """
    )
  }

  func testAssert() {
    @Shared(Stats()) var stats
//    $stats.count.assert { $0 = 0 }
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
    @SharedDependency var statsDependency: Stats
  }
  enum Action {
    case increment
    case incrementStats
    case longLivingEffect
    case noop
    case sharedIncrement
    case sharedDependencyIncrement
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
      case .sharedDependencyIncrement:
        state.statsDependency.count += 1
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
}

private struct Stats: Codable, Equatable {
  var count = 0
}
extension Stats: DependencyKey {
  static let liveValue = Stats()
}
private struct Profile: Equatable {
  @Shared var stats: Stats
}
struct SharedStateWithLiveValue: DependencyKey {
  static let liveValue = SharedStateWithLiveValue()
}
struct SharedStateWithTestValue: TestDependencyKey {
  static let testValue = SharedStateWithTestValue()
}
