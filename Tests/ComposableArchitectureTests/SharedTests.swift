import ComposableArchitecture
import XCTest

@MainActor
final class SharedTests: XCTestCase {
  func testSharing() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: .init(0),
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

  func testDependency() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        profile: Shared(Profile(stats: Shared(Stats()))),
        sharedCount: Shared(0),
        stats: Shared(Stats())
      )
    ) {
      SharedFeature()
    } withDependencies: {
      $0[shared: Stats.self] = Stats(count: 42)
    }
    await store.send(.sharedDependencyIncrement) {
      $0.statsDependency.count = 43
    }
  }

  func testComplexEffect() async {
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
            return .cancel(id: CancelID.timer)
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
    case noop
    case sharedIncrement
    case sharedDependencyIncrement
    case request
  }
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
}

private struct Stats: Equatable {
  var count = 0
}
extension Stats: DependencyKey {
  static let liveValue = Stats()
  static let testValue = Stats()
}
private struct Profile: Equatable {
  @Shared var stats: Stats
}
