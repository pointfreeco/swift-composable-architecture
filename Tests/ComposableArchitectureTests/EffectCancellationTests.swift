import Combine
import XCTest

#if DEBUG
  @testable import ComposableArchitecture
#else
  import ComposableArchitecture
#endif

final class EffectCancellationTests: XCTestCase {
  struct CancelID: Hashable {}
  var cancellables: Set<AnyCancellable> = []

  override func tearDown() {
    super.tearDown()
    self.cancellables.removeAll()
  }

  func testCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    Effect<Never, Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(3)
    XCTAssertEqual(values, [1, 2])
  }

  func testCancelInFlight() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    Effect(subject)
      .cancellable(id: CancelID(), cancelInFlight: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    Effect(subject)
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
      Effect<Never, Never>.cancel(id: CancelID())
        .sink { _ in }
        .store(in: &self.cancellables)
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 0.3)

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
    Effect<Never, Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    mainQueue.run()

    XCTAssertEqual(value, nil)
  }

  #if DEBUG
    func testCancellablesCleanUp_OnComplete() {
      let id = UUID()

      Just(1)
        .eraseToEffect()
        .cancellable(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      XCTAssertNil(cancellationCancellables[CancelToken(id: id)])
    }
  #endif

  #if DEBUG
    func testCancellablesCleanUp_OnCancel() {
      let id = UUID()

      let mainQueue = DispatchQueue.test
      Just(1)
        .delay(for: 1, scheduler: mainQueue)
        .eraseToEffect()
        .cancellable(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      Effect<Int, Never>.cancel(id: id)
        .sink(receiveValue: { _ in })
        .store(in: &self.cancellables)

      XCTAssertNil(cancellationCancellables[CancelToken(id: id)])
    }
  #endif

  func testDoubleCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelID())
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])

    Effect<Never, Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(2)
    XCTAssertEqual(values, [1])
  }

  func testCompleteBeforeCancellation() {
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelID())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    subject.send(1)
    XCTAssertEqual(values, [1])

    subject.send(completion: .finished)
    XCTAssertEqual(values, [1])

    Effect<Never, Never>.cancel(id: CancelID())
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1])
  }

  #if DEBUG
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
        (1...1_000).map { idx -> Effect<Int, Never> in
          let id = ids[idx % 10]

          return Effect.merge(
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
              .flatMap { Effect.cancel(id: id) }
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
        XCTAssertNil(
          cancellationCancellables[CancelToken(id: id)],
          "cancellationCancellables should not contain id \(id)"
        )
      }
    }
  #endif

  #if DEBUG
    func testNestedCancels() {
      let id = UUID()

      var effect = Empty<Void, Never>(completeImmediately: false)
        .eraseToEffect()
        .cancellable(id: 1)

      for _ in 1...1_000 {
        effect = effect.cancellable(id: id)
      }

      effect
        .sink(receiveValue: { _ in })
        .store(in: &cancellables)

      cancellables.removeAll()

      XCTAssertNil(cancellationCancellables[CancelToken(id: id)])
    }
  #endif

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
    let effect = Effect<Int, Never>.merge(
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

    Effect<AnyHashable, Never>.merge(effects)
      .sink { output.append($0) }
      .store(in: &self.cancellables)

    Effect<AnyHashable, Never>
      .cancel(ids: [A(), C()])
      .sink { _ in }
      .store(in: &self.cancellables)

    mainQueue.advance(by: 1)
    XCTAssertEqual(output, [B()])
  }
}
