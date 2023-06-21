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

  func testCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = EffectPublisher(subject)
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    EffectTask<Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(3)
    XCTAssertEqual(values, [1, 2])
  }

  func testCancelInFlight() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    EffectPublisher(subject)
      .cancellable(id: CancelID(), cancelInFlight: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    defer { Task.cancel(id: CancelID()) }
    EffectPublisher(subject)
      .cancellable(id: CancelID(), cancelInFlight: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    subject.send(3)
    XCTAssertEqual(values, [1, 2, 3])
    subject.send(4)
    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    var value: Int?

    Just(1)
      .delay(for: 0.15, scheduler: DispatchQueue.main)
      .eraseToEffect()
      .cancellable(id: CancelID())
      .sink { value = $0 }
      .store(in: &self.cancellables)

    XCTAssertEqual(value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      EffectTask<Never>.cancel(id: CancelID())
        .sink { _ in }
        .store(in: &self.cancellables)
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 1)
    XCTAssertEqual(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let mainQueue = DispatchQueue.test
    var value: Int?

    Just(1)
      .delay(for: 2, scheduler: mainQueue)
      .eraseToEffect()
      .cancellable(id: CancelID())
      .sink { value = $0 }
      .store(in: &self.cancellables)

    XCTAssertEqual(value, nil)

    mainQueue.advance(by: 1)
    EffectTask<Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    mainQueue.run()

    XCTAssertEqual(value, nil)
  }

  func testDoubleCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = EffectPublisher(subject)
      .cancellable(id: CancelID())
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])

    EffectTask<Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(2)
    XCTAssertEqual(values, [1])
  }

  func testCompleteBeforeCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = EffectPublisher(subject)
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    subject.send(1)
    XCTAssertEqual(values, [1])

    subject.send(completion: .finished)
    XCTAssertEqual(values, [1])

    EffectTask<Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1])
  }

  func testSharedId() {
    let mainQueue = DispatchQueue.test

    let effect1 = Just(1)
      .delay(for: 1, scheduler: mainQueue)
      .eraseToEffect()
      .cancellable(id: "id")

    let effect2 = Just(2)
      .delay(for: 2, scheduler: mainQueue)
      .eraseToEffect()
      .cancellable(id: "id")

    var expectedOutput: [Int] = []
    effect1
      .sink { expectedOutput.append($0) }
      .store(in: &cancellables)
    effect2
      .sink { expectedOutput.append($0) }
      .store(in: &cancellables)

    XCTAssertEqual(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [1])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [1, 2])
  }

  func testImmediateCancellation() {
    let mainQueue = DispatchQueue.test

    var expectedOutput: [Int] = []
    // Don't hold onto cancellable so that it is deallocated immediately.
    _ = Deferred { Just(1) }
      .delay(for: 1, scheduler: mainQueue)
      .eraseToEffect()
      .cancellable(id: "id")
      .sink { expectedOutput.append($0) }

    XCTAssertEqual(expectedOutput, [])
    mainQueue.advance(by: 1)
    XCTAssertEqual(expectedOutput, [])
  }

  func testNestedMergeCancellation() {
    let effect = EffectPublisher<Int, Never>.merge(
      (1...2).publisher
        .eraseToEffect()
        .cancellable(id: 1)
    )
    .cancellable(id: 2)

    var output: [Int] = []
    effect
      .sink { output.append($0) }
      .store(in: &cancellables)

    XCTAssertEqual(output, [1, 2])
  }

  @available(*, deprecated)
  func testMultipleCancellations() {
    let mainQueue = DispatchQueue.test
    var output: [AnyHashable] = []

    struct A: Hashable {}
    struct B: Hashable {}
    struct C: Hashable {}

    let ids: [AnyHashable] = [A(), B(), C()]
    let effects = ids.map { id in
      Just(id)
        .delay(for: 1, scheduler: mainQueue)
        .eraseToEffect()
        .cancellable(id: id)
    }

    EffectTask<AnyHashable>.merge(effects)
      .sink { output.append($0) }
      .store(in: &self.cancellables)

    EffectTask<AnyHashable>
      .cancel(ids: [A(), C()])
      .sink { _ in }
      .store(in: &self.cancellables)

    mainQueue.advance(by: 1)
    XCTAssertEqual(output, [B()])
  }
}

#if DEBUG
  @testable import ComposableArchitecture

  final class Internal_EffectCancellationTests: BaseTCATestCase {
    var cancellables: Set<AnyCancellable> = []

    func testCancellablesCleanUp_OnComplete() {
      let id = UUID()

      Just(1)
        .eraseToEffect()
        .cancellable(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      XCTAssertEqual(_cancellationCancellables.exists(at: id, path: NavigationIDPath()), false)
    }

    func testCancellablesCleanUp_OnCancel() {
      let id = UUID()

      let mainQueue = DispatchQueue.test
      Just(1)
        .delay(for: 1, scheduler: mainQueue)
        .eraseToEffect()
        .cancellable(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      EffectPublisher<Int, Never>.cancel(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      XCTAssertEqual(_cancellationCancellables.exists(at: id, path: NavigationIDPath()), false)
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

      let effect = EffectPublisher.merge(
        (1...1_000).map { idx -> EffectPublisher<Int, Never> in
          let id = ids[idx % 10]

          return EffectPublisher.merge(
            Just(idx)
              .delay(
                for: .milliseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
              )
              .eraseToEffect()
              .cancellable(id: id),

            Just(())
              .delay(
                for: .milliseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
              )
              .flatMap { EffectPublisher.cancel(id: id) }
              .eraseToEffect()
          )
        }
      )

      let expectation = self.expectation(description: "wait")
      effect
        .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
        .store(in: &self.cancellables)
      self.wait(for: [expectation], timeout: 999)

      for id in ids {
        XCTAssertEqual(
          _cancellationCancellables.exists(at: id, path: NavigationIDPath()),
          false,
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }

    func testAsyncConcurrentCancels() async {
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
          _cancellationCancellables.exists(at: id, path: NavigationIDPath()),
          false,
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }

    func testNestedCancels() {
      let id = UUID()

      var effect = Empty<Void, Never>(completeImmediately: false)
        .eraseToEffect()
        .cancellable(id: id)

      for _ in 1...1_000 {
        effect = effect.cancellable(id: id)
      }

      effect
        .sink(receiveValue: { _ in })
        .store(in: &cancellables)

      cancellables.removeAll()

      XCTAssertEqual(_cancellationCancellables.exists(at: id, path: NavigationIDPath()), false)
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
