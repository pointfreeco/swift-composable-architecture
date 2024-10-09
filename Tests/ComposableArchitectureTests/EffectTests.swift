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
    await withMainSerialExecutor { [mainQueue] in
      let values = LockIsolated<[Int]>([])

      let effect = Effect<Int>.concatenate(
        .publisher { Just(1).delay(for: 1, scheduler: mainQueue) }
      )

      let task = Task {
        for await n in effect.actions {
          values.withValue { $0.append(n) }
        }
      }

      XCTAssertEqual(values.value, [])

      await mainQueue.advance(by: 1)
      XCTAssertEqual(values.value, [1])

      await mainQueue.run()
      XCTAssertEqual(values.value, [1])

      await task.value
    }
  }

  func testMerge() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      await withMainSerialExecutor {
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
      Reduce { state, action in
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
      Reduce { state, action in
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
}
