import XCTest
import ComposableArchitecture

@MainActor
final class SharedTests: XCTestCase {
  func testSharing() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        sharedCount: .init(0),
        profile: .init(Profile(stats: .init(Stats()))),
        stats: .init(Stats())
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

  func testIncrementalMutation() async {
    let store = TestStore(
      initialState: SharedFeature.State(
        sharedCount: .init(0),
        profile: .init(Profile(stats: .init(Stats()))),
        stats: .init(Stats())
      )
    ) {
      SharedFeature()
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount += 1
    }
  }
}

@Reducer
private struct SharedFeature {
  struct State: Equatable {
    var count = 0
    @Shared2 var sharedCount: Int
    @Shared2 var profile: Profile
    @Shared2 var stats: Stats
  }
  enum Action {
    case increment
    case noop
    case sharedIncrement
    case incrementStats
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none
      case .noop:
        return .none
      case .sharedIncrement:
        state.sharedCount += 1
        return .none
      case .incrementStats:
        state.profile.stats.count += 1
        state.stats.count += 1
        return .none
      }
    }
  }
}

private struct Stats: Equatable {
  var count = 0
}
private struct Profile: Equatable {
  @Shared2 var stats: Stats
}
