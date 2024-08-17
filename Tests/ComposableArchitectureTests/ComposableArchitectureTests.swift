import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest

final class ComposableArchitectureTests: BaseTCATestCase {
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

    let store = await TestStore(initialState: 2) {
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

  func testLongLivingEffects() async {
    enum Action { case end, incr, start }

    let effect = AsyncStream.makeStream(of: Void.self)

    let store = await TestStore(initialState: 0) {
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

//  @MainActor
  func testEffect_AsyncToSync() async throws {
    let asyncEffect = Effect.async { continuation in
      await continuation(1)
    }
    let syncEffect = Effect.sync { continuation in
      let task = asyncEffect.run {
        continuation($0)
      } onTermination: { _ in
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }

//    let syncEffect = Effect.escaping { continuation in
//      let task = asyncEffect.run {
//        continuation($0)
//      } onTermination: { _ in
//        continuation.finish()
//      }
//      return .onComplete {
//        task.cancel()
//      }
//    }

//    let actions = await syncEffect.actions.reduce(into: []) { $0.append($1) }
//    XCTAssertEqual(actions, [1])
    var terminated = false
    var xs: [Int] = []
    let task = syncEffect.run {
      xs.append($0)
    } onTermination: { _ in
      print(#fileID, #line)
      terminated = true
    }
    print(#fileID, #line)
    try await Task.sleep(for: .seconds(1))
    print(#fileID, #line)
    XCTAssertEqual([1], xs)
    XCTAssert(terminated)
    print(#fileID, #line)
    _ = task
  }

  func testEffect_AsyncToAsync() async throws {
    let asyncEffect1 = Effect.async { continuation in
      await continuation(1)
    }
    let asyncEffect2 = Effect.async { continuation in
      for await action in asyncEffect1.actions {
        await continuation(action)
      }
      continuation.onTermination = { _ in }
    }
    var terminated = false
    var xs: [Int] = []
    let task = asyncEffect2.run {
      xs.append($0)
    } onTermination: { _ in
      print(#fileID, #line)
      terminated = true
    }
    print(#fileID, #line)
    try await Task.sleep(for: .seconds(1))
    print(#fileID, #line)
    XCTAssertEqual([1], xs)
    XCTAssert(terminated)
    print(#fileID, #line)
  }

  func testEffect_SyncToSync() async throws {
    let syncEffect1 = Effect.sync { continuation in
      continuation(1)
      continuation.finish()
    }
    let syncEffect2 = Effect.sync { continuation in
      let task = syncEffect1.run {
        continuation($0)
      } onTermination: { _ in
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
    var terminated = false
    var xs: [Int] = []
    let task = syncEffect2.run {
      xs.append($0)
    } onTermination: { _ in
      print(#fileID, #line)
      terminated = true
    }
    print(#fileID, #line)
    try await Task.sleep(for: .seconds(1))
    print(#fileID, #line)
    XCTAssertEqual([1], xs)
    XCTAssert(terminated)
    print(#fileID, #line)
  }

  func testEffect_SyncToAsync() async throws {
    let syncEffect = Effect.sync { continuation in
      continuation(1)
      continuation.finish()
    }
    let asyncEffect = Effect.async { continuation in
      for await action in syncEffect.actions {
        await continuation(action)
      }
    }
    var terminated = false
    var xs: [Int] = []
    let task = asyncEffect.run {
      xs.append($0)
    } onTermination: { _ in
      print(#fileID, #line)
      terminated = true
    }
    print(#fileID, #line)
    try await Task.sleep(for: .seconds(1))
    print(#fileID, #line)
    XCTAssertEqual([1], xs)
    XCTAssert(terminated)
    print(#fileID, #line)
  }

//  func testCancellation() async {
//    let mainQueue = DispatchQueue.test
//
//    enum Action: Equatable {
//      case cancel
//      case incr
//      case response(Int)
//    }
//
//    let store = await TestStore(initialState: 0) {
//      Reduce<Int, Action> { state, action in
//        enum CancelID { case sleep }
//
//        switch action {
//        case .cancel:
//          return .cancel(id: CancelID.sleep)
//
//        case .incr:
//          state += 1
//          return .run { [state] send in
////            try await mainQueue.sleep(for: .seconds(1))
////            await send(.response(state * state))
//          }
//          .cancellable(id: CancelID.sleep)
//
//        case let .response(value):
//          state = value
//          return .none
//        }
//      }
//    }
//
//    await store.send(.incr) { $0 = 1 }
////    await mainQueue.advance(by: .seconds(1))
////    await store.receive(.response(1))
//
////    await store.send(.incr) { $0 = 1 }
////    await store.send(.cancel)
////    await store.finish()
//  }
}
