import Combine
@_spi(Canary) @_spi(Internals) import ComposableArchitecture
import XCTest

final class EffectTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  func testConcatenate() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      await withMainSerialExecutor {
        let clock = TestClock()
        let values = LockIsolated<[Int]>([])

        let effect = Effect<Int>.concatenate(
          (1...3).map { count in
            .run { send in
              try await clock.sleep(for: .seconds(count))
              await send(count)
            }
          }
        )

        let task = Task {
          for await n in effect.actions {
            values.withValue { $0.append(n) }
          }
        }

        XCTAssertEqual(values.value, [])

        await clock.advance(by: .seconds(1))
        XCTAssertEqual(values.value, [1])

        await clock.advance(by: .seconds(2))
        XCTAssertEqual(values.value, [1, 2])

        await clock.advance(by: .seconds(3))
        XCTAssertEqual(values.value, [1, 2, 3])

        await clock.run()
        XCTAssertEqual(values.value, [1, 2, 3])

        await task.value
      }
    }
  }

  func testConcatenateOneEffect() async {
    let values = LockIsolated<[Int]>([])

    let effect = Effect<Int>.concatenate(
      .publisher { Just(1).delay(for: 1, scheduler: self.mainQueue) }
    )

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])

    await self.mainQueue.advance(by: 1)
    XCTAssertEqual(values.value, [1])

    await self.mainQueue.run()
    XCTAssertEqual(values.value, [1])

    await task.value
  }

  func testMerge() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      let clock = TestClock()

      let effect = Effect<Int>.merge(
        (1...3).map { count in
          .run { send in
            try await clock.sleep(for: .seconds(count))
            await send(count)
          }
        }
      )

      let values = LockIsolated<[Int]>([])

      let task = Task {
        for await n in effect.actions {
          values.withValue { $0.append(n) }
        }
      }

      XCTAssertEqual(values.value, [])

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(values.value, [1])

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(values.value, [1, 2])

      await clock.advance(by: .seconds(1))
      XCTAssertEqual(values.value, [1, 2, 3])

      await task.value
    }
  }

  func testDoubleCancelInFlight() async {
    var result: Int?

    let effect = Effect.send(42)
      .cancellable(id: "id", cancelInFlight: true)
      .cancellable(id: "id", cancelInFlight: true)

    for await n in effect.actions {
      XCTAssertNil(result)
      result = n
    }

    XCTAssertEqual(result, 42)
  }

  @Reducer
  fileprivate struct Feature_testDependenciesTransferredToEffects_Task {
    enum Action: Equatable {
      case tap
      case response(Int)
    }
    @Dependency(\.date) var date
    var body: some Reducer<Int, Action> {
      Reduce(internal: { state, action in
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      })
    }
  }
  func testDependenciesTransferredToEffects_Task() async {
    let store = await TestStore(initialState: 0) {
      Feature_testDependenciesTransferredToEffects_Task()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    }

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  @Reducer
  fileprivate struct Feature_testDependenciesTransferredToEffects_Run {
    enum Action: Equatable {
      case tap
      case response(Int)
    }
    @Dependency(\.date) var date
    var body: some Reducer<Int, Action> {
      Reduce(internal: { state, action in
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      })
    }
  }

  func testDependenciesTransferredToEffects_Run() async {
    let store = await TestStore(initialState: 0) {
      Feature_testDependenciesTransferredToEffects_Run()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    }

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testMap() async {
    @Dependency(\.date) var date
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
    } operation: {
      Effect.send(()).map { date() }
    }
    var output: Date?
    for await date in effect.actions {
      XCTAssertNil(output)
      output = date
    }
    XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))

    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      let effect = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      } operation: {
        Effect<Void>.run { send in await send(()) }.map { date() }
      }
      output = nil
      for await date in effect.actions {
        XCTAssertNil(output)
        output = date
      }
      XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
    }
  }

  func testCanary1() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: Task {}, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }
  func testCanary2() async {
    for _ in 1...100 {
      let task = TestStoreTask(rawValue: nil, timeout: NSEC_PER_SEC)
      await task.finish()
    }
  }

//  func testSyncMerge() async {
//    let effect = Effect<Int>.merge(
//      .sync { $0(1); $0.finish() },
//      .sync { $0(2); $0.finish() },
//      .sync { $0(3); $0.finish() }
//    )
//
//    let actions = await effect.actions.reduce(into: []) { $0.append($1) }
//    XCTAssertEqual(actions, [1, 2, 3])
//  }
//
//  func testSyncConcatenate() async {
//    let effect = Effect<Int>.concatenate(
//      .sync { $0(1); $0.finish() },
//      .sync { $0(2); $0.finish() },
//      .sync { $0(3); $0.finish() }
//    )
//
//    let actions = await effect.actions.reduce(into: []) { $0.append($1) }
//    XCTAssertEqual(actions, [1, 2, 3])
//  }

  func testTaskGroupConcat() async throws {
    let xs = LockIsolated<[Int]>([])
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        print("Starting first task")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        xs.withValue { $0.append(1) }
        print(xs.value)
      }
      try await group.waitForAll()
      group.addTask {
        print("Starting second task")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        xs.withValue { $0.append(2) }
        print(xs.value)
      }
    }

    XCTAssertEqual(xs.value, [1, 2])
  }

  func testSyncCancellation() async throws {
    let effect = Effect<Int>.sync { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        continuation(42)
        continuation.finish()
      }
    }
      .cancellable(id: "id")
    let xs = LockIsolated([Int]())

    Task {
      try await Task.sleep(nanoseconds: 1_000_000)
      Task.cancel(id: "id")
    }

    switch effect.operation {
    case .none:
      XCTFail()
    case .sync(let operation):
      let continuation = Send<Int>.Continuation { x in
        xs.withValue { $0.append(x) }
      }
      operation(continuation)

    case .run(_, _):
      XCTFail()
    }

    try await Task.sleep(nanoseconds: 1_000_000_000)
    XCTAssertEqual(xs.value, [])
  }

  func testSyncPublisherCancellation() async throws {
    let effect = _EffectPublisher(
      Effect<Int>.sync { continuation in
        continuation.onTermination = { _ in
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          continuation(42)
          continuation.finish()
        }
      }
    )

    let cancellable = effect.sink { _ in
      XCTFail()
    }
    cancellable.cancel()
  }

  func testPublisherSyncCancellation() async throws {
    let effect = Effect.publisher {
      Future<Int, Never> { continuation in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          continuation(.success(42))
        }
      }
    }
      .cancellable(id: "id")

    let xs = LockIsolated([Int]())

    Task {
      try await Task.sleep(nanoseconds: 1_000_000)
      Task.cancel(id: "id")
    }

    switch effect.operation {
    case .none:
      XCTFail()
    case .sync(let operation):
      let continuation = Send<Int>.Continuation { x in
        xs.withValue { $0.append(x) }
      }
      operation(continuation)

    case .run(_, _):
      XCTFail()
    }

    try await Task.sleep(nanoseconds: 1_000_000_000)
    XCTAssertEqual(xs.value, [])
  }


  func testSyncDependencies() async {
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
    } operation: {
      Effect<Never>.sync {
        @Dependency(\.date.now) var now
        XCTAssertEqual(now, Date(timeIntervalSinceReferenceDate: 0))
        $0.finish()
      }
    }
    for await _ in effect.actions {}
  }

  func testSyncDependencies_Cancellable() async {
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
    } operation: {
      Effect<Never>.sync {
        @Dependency(\.date.now) var now
        XCTAssertEqual(now, Date(timeIntervalSinceReferenceDate: 0))
        $0.finish()
      }
      .cancellable(id: "id")
    }
    for await _ in effect.actions {}
  }

  func testSyncDependencies_publisher() async {
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
    } operation: {
      Effect.publisher {
        _EffectPublisher<Never>(
          Effect<Never>.sync {
            @Dependency(\.date.now) var now
            XCTAssertEqual(now, Date(timeIntervalSinceReferenceDate: 0))
            $0.finish()
          }
        )
      }
    }
    for await _ in effect.actions {}
  }

  func testSyncDependencies_merge() async {
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
    } operation: {
      Effect<Never>.merge([
        Effect<Never>.sync {
          @Dependency(\.date.now) var now
          XCTAssertEqual(now, Date(timeIntervalSinceReferenceDate: 0))
          $0.finish()
        }
      ])
    }
    for await _ in effect.actions {}
  }

  func testSyncDependencies_concat() async {
    let effect = withDependencies {
      $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
    } operation: {
      Effect<Never>.concatenate([
        Effect<Never>.sync {
          @Dependency(\.date.now) var now
          XCTAssertEqual(now, Date(timeIntervalSinceReferenceDate: 0))
          $0.finish()
        }
      ])
    }
    for await _ in effect.actions {}
  }
}

@testable import ComposableArchitecture
