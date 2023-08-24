import Combine
@testable @_spi(Canary)@_spi(Internals) import ComposableArchitecture
@testable import ComposableArchitecture
import XCTest

@MainActor
final class EffectTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []
  let mainQueue = DispatchQueue.test

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
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
  #endif

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

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
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
  #endif

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

  func testDependenciesTransferredToEffects_Task() async {
    struct Feature: Reducer {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action> {
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(initialState: 0) {
      Feature()
        .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
    }

    await store.send(.tap).finish(timeout: NSEC_PER_SEC)
    await store.receive(.response(1_234_567_890)) {
      $0 = 1_234_567_890
    }
  }

  func testDependenciesTransferredToEffects_Run() async {
    struct Feature: Reducer {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      func reduce(into state: inout Int, action: Action) -> Effect<Action> {
        switch action {
        case .tap:
          return .run { send in
            await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
          }
        case let .response(value):
          state = value
          return .none
        }
      }
    }
    let store = TestStore(initialState: 0) {
      Feature()
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

  func testPublisher() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect.publisher { subject }

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    await Task.megaYield()

    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    subject.send(2)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2])

    subject.send(3)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2, 3])

    subject.send(completion: .finished)
    await task.value
  }

  func testConcatenateNewStyle() async {
    let values = LockIsolated<[Int]>([])

    let effect = Effect<Int>.concatenate(
      .send(1),
      .send(2)
    )

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1, 2])
  }

  func testMergeNewStyle() async {
    let values = LockIsolated<[Int]>([])

    let effect = Effect<Int>.merge(
      .send(1),
      .send(2)
    )

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1, 2])
  }

  func testSend() async {
    let values = LockIsolated<[Int]>([])

    let effect = Effect<Int>.send(1)

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(values.value, [])
    await task.value
    XCTAssertEqual(values.value, [1])
  }

  func testSyncAsyncSync() async {
    let values = LockIsolated([Int]())

    let effect: Effect<Int> = .concatenate(
      .send(1),

      Effect(operations: [.init(async: (nil, { await $0(2) }))]),

        .send(3)
    )

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2, 3])
  }

  func testAsyncSyncSync() async {
    let values = LockIsolated([Int]())

    let effect: Effect<Int> = .concatenate(
      Effect(operations: [.init(async: (nil, { $0(1) }))]),
      .send(2)
    )

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2])
  }

  func testAsyncSyncAsync() async {
    let values = LockIsolated([Int]())

    let effect: Effect<Int> = .concatenate(
      Effect(operations: [.init(async: (nil, { await $0(1) }))]),
      .send(2),
      Effect(operations: [.init(async: (nil, { await $0(3) }))])
    )

    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1, 2, 3])
  }

  func testCancelForeverSyncEffect() async throws {
    let effect = Effect<Int>(operations: [
      Effect<Int>._Operation(sync: { _ in })
    ])
      .cancellable(id: "id")

    let task = Task {
      for await _ in effect.actions {}
    }

    try await Task.sleep(for: .seconds(0.1))
    Task.cancel(id: "id")

    await task.value
  }

  func testForeverSyncCancellable() async throws {
    let effect = Effect<Int>.concatenate(
      Effect<Int>(operations: [
        Effect<Int>._Operation(sync: {
          $0.onTermination = { _ in 
            print("!!!")
          }
        })
      ])
      .cancellable(id: "forever"),

      .send(1)
    )
      .cancellable(id: "id1")
      .cancellable(id: "id2")

    let values = LockIsolated([Int]())
    let task = Task {
      for await int in effect.actions {
        values.withValue { $0.append(int) }
      }
    }

    try await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(values.value, [])
    Task.cancel(id: "forever")
    await task.value
    XCTAssertEqual(values.value, [1])
  }

  func testSyncForeverSyncSync() async throws {
    let effect = Effect<Int>.concatenate(
      .init(operations: [.init(sync: { $0(1); $0.finish() })]),
      .init(operations: [.init(sync: { send in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          send(2)
          send.finish()
        }
      })]).map { $0 },
      .init(operations: [.init(sync: { $0(3); $0.finish() })])
    )

    let values = LockIsolated([Int]())

      for await int in effect.actions {
        values.withValue { $0.append(int) }
      }

    XCTAssertEqual(values.value, [1, 2, 3])
  }

  func testOnComplete() async {
    let didComplete = LockIsolated(false)
    let effect = Effect<Int>.publisher {
      Just(1)
    }
      .onComplete {
        didComplete.setValue(true)
      }

    let values = LockIsolated([Int]())
    for await int in effect.actions {
      values.withValue { $0.append(int) }
    }

    XCTAssertEqual(values.value, [1])
    XCTAssertEqual(didComplete.value, true)
  }
}
