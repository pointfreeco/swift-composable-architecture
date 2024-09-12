import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class EffectCancellationTests: BaseTCATestCase {
  struct CancelID: Hashable {}
  var cancellables: Set<AnyCancellable> = []

  override func tearDown() {
    super.tearDown()
    self.cancellables.removeAll()
  }

  override func invokeTest() {
    withMainSerialExecutor {
      super.invokeTest()
    }
  }

  func testCancellation() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect.publisher { subject }
      .cancellable(id: CancelID())

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    await Task.megaYield()
    XCTAssertEqual(values.value, [])
    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])
    subject.send(2)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2])

    Task.cancel(id: CancelID())

    subject.send(3)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2])

    await task.value
  }

  func testCancelInFlight() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect1 = Effect.publisher { subject }
      .cancellable(id: CancelID(), cancelInFlight: true)

    let task1 = Task {
      for await n in effect1.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    XCTAssertEqual(values.value, [])
    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])
    subject.send(2)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2])

    defer { Task.cancel(id: CancelID()) }

    let effect2 = Effect.publisher { subject }
      .cancellable(id: CancelID(), cancelInFlight: true)

    let task2 = Task {
      for await n in effect2.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    subject.send(3)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2, 3])
    subject.send(4)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 2, 3, 4])

    Task.cancel(id: CancelID())
    await task1.value
    await task2.value
  }

  func testCancellationAfterDelay() async {
    let result = LockIsolated<Int?>(nil)

    let effect = Effect.publisher {
      Just(1)
        .delay(for: 0.15, scheduler: DispatchQueue.main)
    }
    .cancellable(id: CancelID())

    let task = Task {
      for await n in effect.actions {
        result.setValue(n)
      }
    }

    XCTAssertEqual(result.value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      Task.cancel(id: CancelID())
    }

    await task.value
    XCTAssertEqual(result.value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() async {
    let mainQueue = DispatchQueue.test
    let result = LockIsolated<Int?>(nil)

    let effect = Effect.publisher {
      Just(1)
        .delay(for: 2, scheduler: mainQueue)
    }
    .cancellable(id: CancelID())

    let task = Task {
      for await value in effect.actions {
        result.setValue(value)
      }
    }
    await Task.megaYield()

    XCTAssertEqual(result.value, nil)

    await mainQueue.advance(by: 1)

    Task.cancel(id: CancelID())

    await mainQueue.run()

    XCTAssertEqual(result.value, nil)

    await task.value
  }

  func testDoubleCancellation() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect.publisher { subject }
      .cancellable(id: CancelID())
      .cancellable(id: CancelID())

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    XCTAssertEqual(values.value, [])

    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    Task.cancel(id: CancelID())

    subject.send(2)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    await task.value

    XCTAssertEqual(values.value, [1])
  }

  func testCompleteBeforeCancellation() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect.publisher { subject }
      .cancellable(id: CancelID())

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    subject.send(completion: .finished)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    Task.cancel(id: CancelID())

    await task.value
    XCTAssertEqual(values.value, [1])
  }

  func testSharedId() async {
    let mainQueue = DispatchQueue.test

    let effect1 = Effect.publisher {
      Just(1)
        .delay(for: 1, scheduler: mainQueue)
    }
    .cancellable(id: "id")

    let effect2 = Effect.publisher {
      Just(2)
        .delay(for: 2, scheduler: mainQueue)
    }
    .cancellable(id: "id")

    let expectedOutput = LockIsolated<[Int]>([])
    let task1 = Task {
      for await n in effect1.actions {
        expectedOutput.withValue { $0.append(n) }
      }
    }
    let task2 = Task {
      for await n in effect2.actions {
        expectedOutput.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    XCTAssertEqual(expectedOutput.value, [])
    await mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput.value, [1])
    await mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput.value, [1, 2])

    await task1.value
    await task2.value
  }

  func testImmediateCancellation() async {
    let mainQueue = DispatchQueue.test

    let expectedOutput = LockIsolated<[Int]>([])
    let effect = Effect.run { send in
      try await mainQueue.sleep(for: .seconds(1))
      await send(1)
    }
    .cancellable(id: "id")

    let task = Task {
      for await n in effect.actions {
        expectedOutput.withValue { $0.append(n) }
      }
    }

    XCTAssertEqual(expectedOutput.value, [])
    task.cancel()

    await mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput.value, [])

    await task.value
  }

  func testNestedMergeCancellation() async {
    let effect = Effect<Int>.merge(
      .publisher { (1...2).publisher }
        .cancellable(id: 1)
    )
    .cancellable(id: 2)

    var output: [Int] = []
    for await n in effect.actions {
      output.append(n)
    }
    XCTAssertEqual(output, [1, 2])
  }
}

#if DEBUG
  @testable import ComposableArchitecture

  final class Internal_EffectCancellationTests: BaseTCATestCase {
    var cancellables: Set<AnyCancellable> = []

    func testCancellablesCleanUp_OnComplete() async {
      let id = UUID()

      for await _ in Effect.send(1).cancellable(id: id).actions {}

      XCTAssertEqual(
        _cancellationCancellables.withValue { $0.exists(at: id, path: NavigationIDPath()) },
        false
      )
    }

    func testCancellablesCleanUp_OnCancel() async {
      let id = UUID()

      let mainQueue = DispatchQueue.test
      let effect = Effect.publisher {
        Just(1)
          .delay(for: 1, scheduler: mainQueue)
      }
      .cancellable(id: id)

      let task = Task {
        for await _ in effect.actions {
        }
      }
      await Task.megaYield()

      Task.cancel(id: id)

      await task.value

      XCTAssertEqual(
        _cancellationCancellables.withValue { $0.exists(at: id, path: NavigationIDPath()) },
        false
      )
    }

    func testConcurrentCancels() {
      let queues = [
        DispatchQueue.main,
        DispatchQueue.global(qos: .background),
        DispatchQueue.global(qos: .default),
        DispatchQueue.global(qos: .unspecified),
        DispatchQueue.global(qos: .userInitiated),
        DispatchQueue.global(qos: .userInteractive),
        DispatchQueue.global(qos: .utility),
      ]
      let ids = (1...10).map { _ in UUID() }

      let effect = Effect.merge(
        (1...1_000).map { idx -> Effect<Int> in
          let id = ids[idx % 10]

          return .merge(
            .publisher {
              Just(idx)
                .delay(
                  for: .milliseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
                )
            }
            .cancellable(id: id),

            .publisher {
              Empty()
                .delay(
                  for: .milliseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
                )
                .handleEvents(receiveCompletion: { _ in Task.cancel(id: id) })
            }
          )
        }
      )

      let expectation = self.expectation(description: "wait")
      // NB: `for await _ in effect.actions` blows the stack with 1,000 merged publishers
      _EffectPublisher(effect)
        .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
        .store(in: &self.cancellables)
      self.wait(for: [expectation], timeout: 999)

      for id in ids {
        XCTAssertEqual(
          _cancellationCancellables.withValue { $0.exists(at: id, path: NavigationIDPath()) },
          false,
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }

    func testAsyncConcurrentCancels() async {
      uncheckedUseMainSerialExecutor = false
      await Task.yield()
      XCTAssertTrue(!Thread.isMainThread)
      let ids = (1...100).map { _ in UUID() }

      let areCancelled = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
        (1...10_000).forEach { index in
          let id = ids[index.quotientAndRemainder(dividingBy: ids.count).remainder]
          group.addTask {
            await withTaskCancellation(id: id) {
              nil == (try? await Task.sleep(nanoseconds: 2_000_000_000))
            }
          }
          Task {
            try? await Task.sleep(nanoseconds: .random(in: 1_000_000...2_000_000))
            Task.cancel(id: id)
          }
        }
        return await group.reduce(into: [Bool]()) { $0.append($1) }
      }

      XCTAssertTrue(areCancelled.allSatisfy({ isCancelled in isCancelled }))

      for id in ids {
        XCTAssertEqual(
          _cancellationCancellables.withValue { $0.exists(at: id, path: NavigationIDPath()) },
          false,
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }

    func testCancelIDHash() {
      struct CancelID1: Hashable {}
      struct CancelID2: Hashable {}
      let id1 = _CancelID(id: CancelID1(), navigationIDPath: NavigationIDPath())
      let id2 = _CancelID(id: CancelID2(), navigationIDPath: NavigationIDPath())
      XCTAssertNotEqual(id1, id2)
      // NB: We hash the type of the cancel ID to give more variance in the hash since all empty
      //     structs in Swift have the same hash value.
      XCTAssertNotEqual(id1.hashValue, id2.hashValue)
    }
  }
#endif
