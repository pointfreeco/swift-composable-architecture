import Combine
import ComposableArchitecture
import XCTest

final class StoreActorTests: BaseTCATestCase {
  func testBasics() async throws {
    let store = StoreActor(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.setIsolation(store))

    var state = await store.state
    XCTAssertEqual(state.count, 0)

    await store.send(.tap)
    state = await store.state
    XCTAssertEqual(state.count, 1)

    try await Task.sleep(for: .seconds(0.1))

    state = await store.state
    XCTAssertEqual(state.count, 0)
  }
}

@Reducer
private struct Feature {
  struct State {
    var count = 0
    var isolation: (any Actor)?
  }
  enum Action {
    case response
    case setIsolation(any Actor)
    case tap
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      defer {
        state.isolation!.assertIsolated()
      }
      switch action {
      case .response:
        state.count -= 1
        return .none
      case .setIsolation(let isolation):
        state.isolation = isolation
        return .none
      case .tap:
        state.count += 1
        return .run { send in await send(.response) }
      }
    }
  }
}
