import XCTest
import ComposableArchitecture

@MainActor
final class SharedTests: XCTestCase {
  func testSharing() async {
    let store = TestStore(initialState: SharedFeature.State(sharedCount: .init(0))) {
      SharedFeature()
    }
    await store.send(.noop)
    await store.send(.increment) {
      $0.count = 1
    }
    await store.send(.sharedIncrement) {
      $0.sharedCount = 1
    }
  }
}

@Reducer
private struct SharedFeature {
  struct State: Equatable {
    var count = 0
    @Shared2 var sharedCount: Int
  }
  enum Action {
    case increment
    case noop
    case sharedIncrement
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
      }
    }
  }
}
