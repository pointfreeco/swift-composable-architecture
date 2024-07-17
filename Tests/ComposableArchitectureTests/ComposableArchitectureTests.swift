import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest

final class ComposableArchitectureTests: BaseTCATestCase {
  @MainActor
  func testScheduling() async {
    struct Counter: Reducer {
      typealias State = Int
      enum Action: Equatable {
        case incrAndSquareLater
        case incrNow
        case squareNow
      }
      @Dependency(\.mainQueue) var mainQueue
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .incrAndSquareLater:
            return .run { send in
              await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                  try await self.mainQueue.sleep(for: .seconds(2))
                  await send(.incrNow)
                }
                group.addTask {
                  try await self.mainQueue.sleep(for: .seconds(1))
                  await send(.squareNow)
                }
                group.addTask {
                  try await self.mainQueue.sleep(for: .seconds(2))
                  await send(.squareNow)
                }
              }
            }
          case .incrNow:
            state += 1
            return .none
          case .squareNow:
            state *= state
            return .none
          }
        }
      }
    }

    let mainQueue = DispatchQueue.test

    let store = TestStore(initialState: 2) {
      Counter()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 1)
    await store.receive(.squareNow) { $0 = 4 }
    await mainQueue.advance(by: 1)
    await store.receive(.incrNow) { $0 = 5 }
    await store.receive(.squareNow) { $0 = 25 }

    await store.send(.incrAndSquareLater)
    await mainQueue.advance(by: 2)
    await store.receive(.squareNow) { $0 = 625 }
    await store.receive(.incrNow) { $0 = 626 }
    await store.receive(.squareNow) { $0 = 391876 }
  }

  @MainActor
  func testSimultaneousWorkOrdering() {
    var cancellables: Set<AnyCancellable> = []
    defer { _ = cancellables }

    let mainQueue = DispatchQueue.test

    var values: [Int] = []
    mainQueue.schedule(after: mainQueue.now, interval: 1) { values.append(1) }
      .store(in: &cancellables)
    mainQueue.schedule(after: mainQueue.now, interval: 2) { values.append(42) }
      .store(in: &cancellables)

    XCTAssertEqual(values, [])
    mainQueue.advance()
    XCTAssertEqual(values, [1, 42])
    mainQueue.advance(by: 2)
    XCTAssertEqual(values, [1, 42, 1, 1, 42])
  }

  @MainActor
  func testLongLivingEffects() async {
    enum Action { case end, incr, start }

    let effect = AsyncStream.makeStream(of: Void.self)

    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .end:
          return .run { _ in
            effect.continuation.finish()
          }
        case .incr:
          state += 1
          return .none
        case .start:
          return .run { send in
            for await _ in effect.stream {
              await send(.incr)
            }
          }
        }
      }
    }

    await store.send(.start)
    await store.send(.incr) { $0 = 1 }
    effect.continuation.yield()
    await store.receive(.incr) { $0 = 2 }
    await store.send(.end)
  }

  @MainActor
  func testCancellation() async {
    let mainQueue = DispatchQueue.test

    enum Action: Equatable {
      case cancel
      case incr
      case response(Int)
    }

    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        enum CancelID { case sleep }

        switch action {
        case .cancel:
          return .cancel(id: CancelID.sleep)

        case .incr:
          state += 1
          return .run { [state] send in
            try await mainQueue.sleep(for: .seconds(1))
            await send(.response(state * state))
          }
          .cancellable(id: CancelID.sleep)

        case let .response(value):
          state = value
          return .none
        }
      }
    }

    await store.send(.incr) { $0 = 1 }
    await mainQueue.advance(by: .seconds(1))
    await store.receive(.response(1))

    await store.send(.incr) { $0 = 2 }
    await store.send(.cancel)
    await store.finish()
  }
}
