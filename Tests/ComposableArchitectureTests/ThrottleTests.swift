import Combine
import ComposableArchitecture
import XCTest

@MainActor
final class EffectThrottleTests: BaseTCATestCase {
  let mainQueue = DispatchQueue.test

  func testThrottleLatest_Publisher() async {
    let store = TestStore(initialState: ThrottleFeature.State()) {
      ThrottleFeature(id: #function, latest: true)
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.tap(1))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(1)) {
      $0.count = 1
    }

    await store.send(.tap(2))
    await self.mainQueue.advance()
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(3))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(4))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(5))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.receive(.throttledResponse(5)) {
      $0.count = 5
    }
  }

  func testThrottleLatest_Async() async {
    let store = TestStore(initialState: ThrottleFeature.State()) {
      ThrottleFeature(id: #function, latest: true)
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.tap(1))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(1)) {
      $0.count = 1
    }

    await store.send(.tap(2))
    await self.mainQueue.advance()
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(3))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(4))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(5))
    await self.mainQueue.advance(by: .seconds(1))
    await store.receive(.throttledResponse(5)) {
      $0.count = 5
    }
  }

  func testThrottleFirst_Publisher() async {
    let store = TestStore(initialState: ThrottleFeature.State()) {
      ThrottleFeature(id: #function, latest: false)
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.tap(1))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(1)) {
      $0.count = 1
    }

    await store.send(.tap(2))
    await self.mainQueue.advance()
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(3))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(4))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.skipReceivedActions(strict: false)
    XCTAssertEqual(store.state.count, 1)

    await store.send(.tap(5))
    await self.mainQueue.advance(by: .seconds(0.25))
    await store.receive(.throttledResponse(2)) {
      $0.count = 2
    }
  }

  func testThrottleAfterInterval_Publisher() async {
    let store = TestStore(initialState: ThrottleFeature.State()) {
      ThrottleFeature(id: #function, latest: true)
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.tap(1))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(1)) {
      $0.count = 1
    }

    await self.mainQueue.advance(by: .seconds(1))
    await store.send(.tap(2))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(2)) {
      $0.count = 2
    }
  }

  func testThrottleEmitsFirstValueOnce_Publisher() async {
    let store = TestStore(initialState: ThrottleFeature.State()) {
      ThrottleFeature(id: #function, latest: true)
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.tap(1))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(1)) {
      $0.count = 1
    }

    await self.mainQueue.advance(by: .seconds(1))
    await store.send(.tap(2))
    await self.mainQueue.advance()
    await store.receive(.throttledResponse(2)) {
      $0.count = 2
    }
  }
}

struct ThrottleFeature: Reducer {
  struct State: Equatable {
    var count = 0
  }
  enum Action: Equatable {
    case tap(Int)
    case throttledResponse(Int)
  }
  let id: String
  let latest: Bool
  @Dependency(\.mainQueue) var mainQueue
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .tap(value):
      return .send(.throttledResponse(value))
        .throttle(id: self.id, for: .seconds(1), scheduler: self.mainQueue, latest: self.latest)
    case let .throttledResponse(value):
      state.count = value
      return .none
    }
  }
}
