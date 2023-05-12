import Combine
import CombineSchedulers
import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import XCTest

@MainActor
final class ComposableArchitectureTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  func testScheduling() async {
    struct Counter: ReducerProtocol {
      typealias State = Int
      enum Action: Equatable {
        case incrAndSquareLater
        case incrNow
        case squareNow
      }
      @Dependency(\.mainQueue) var mainQueue
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .incrAndSquareLater:
          return .merge(
            .send(.incrNow)
              .delay(for: 2, scheduler: self.mainQueue)
              .eraseToEffect(),
            .send(.squareNow)
              .delay(for: 1, scheduler: self.mainQueue)
              .eraseToEffect(),
            .send(.squareNow)
              .delay(for: 2, scheduler: self.mainQueue)
              .eraseToEffect()
          )
        case .incrNow:
          state += 1
          return .none
        case .squareNow:
          state *= state
          return .none
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

  func testSimultaneousWorkOrdering() {
    let mainQueue = DispatchQueue.test

    var values: [Int] = []
    mainQueue.schedule(after: mainQueue.now, interval: 1) { values.append(1) }
      .store(in: &self.cancellables)
    mainQueue.schedule(after: mainQueue.now, interval: 2) { values.append(42) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    mainQueue.advance()
    XCTAssertEqual(values, [1, 42])
    mainQueue.advance(by: 2)
    XCTAssertEqual(values, [1, 42, 1, 1, 42])
  }

  func testLongLivingEffects() async {
    enum Action { case end, incr, start }

    let effect = AsyncStream.makeStream(of: Void.self)

    let store = TestStore(initialState: 0) {
      Reduce<Int, Action> { state, action in
        switch action {
        case .end:
          return .fireAndForget {
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

  func testCancellation() async {
    await withMainSerialExecutor {
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
}
