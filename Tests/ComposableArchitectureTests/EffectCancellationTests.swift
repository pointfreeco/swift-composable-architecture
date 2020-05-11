import Combine
import XCTest

@testable import ComposableArchitecture

final class EffectCancellationTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  override func setUp() {
    super.setUp()
    resetCancellables()
  }

  func testCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelToken())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(3)
    XCTAssertEqual(values, [1, 2])
  }

  func testCancelInFlight() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    Effect(subject)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])
    subject.send(2)
    XCTAssertEqual(values, [1, 2])

    Effect(subject)
      .cancellable(id: CancelToken(), cancelInFlight: true)
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    subject.send(3)
    XCTAssertEqual(values, [1, 2, 3])
    subject.send(4)
    XCTAssertEqual(values, [1, 2, 3, 4])
  }

  func testCancellationAfterDelay() {
    struct CancelToken: Hashable {}
    var value: Int?

    Just(1)
      .delay(for: 0.5, scheduler: DispatchQueue.main)
      .eraseToEffect()
      .cancellable(id: CancelToken())
      .sink { value = $0 }
      .store(in: &self.cancellables)

    XCTAssertEqual(value, nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      _ = Effect<Never, Never>.cancel(id: CancelToken())
        .sink { _ in }
        .store(in: &self.cancellables)
    }

    _ = XCTWaiter.wait(for: [self.expectation(description: "")], timeout: 0.1)

    XCTAssertEqual(value, nil)
  }

  func testCancellationAfterDelay_WithTestScheduler() {
    let scheduler = DispatchQueue.testScheduler
    struct CancelToken: Hashable {}
    var value: Int?

    Just(1)
      .delay(for: 2, scheduler: scheduler)
      .eraseToEffect()
      .cancellable(id: CancelToken())
      .sink { value = $0 }
      .store(in: &self.cancellables)

    XCTAssertEqual(value, nil)

    scheduler.advance(by: 1)
    Effect<Never, Never>.cancel(id: CancelToken())
      .sink { _ in }
      .store(in: &self.cancellables)

    scheduler.run()

    XCTAssertEqual(value, nil)
  }

  func testCancellablesCleanUp_OnComplete() {
    Just(1)
      .eraseToEffect()
      .cancellable(id: 1)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }

  func testCancellablesCleanUp_OnCancel() {
    let scheduler = DispatchQueue.testScheduler
    Just(1)
      .delay(for: 1, scheduler: scheduler)
      .eraseToEffect()
      .cancellable(id: 1)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    Effect<Int, Never>.cancel(id: 1)
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }

  func testDoubleCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelToken())
      .cancellable(id: CancelToken())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [])
    subject.send(1)
    XCTAssertEqual(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .sink { _ in }
      .store(in: &self.cancellables)

    subject.send(2)
    XCTAssertEqual(values, [1])
  }

  func testCompleteBeforeCancellation() {
    struct CancelToken: Hashable {}
    var values: [Int] = []

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect(subject)
      .cancellable(id: CancelToken())

    effect
      .sink { values.append($0) }
      .store(in: &self.cancellables)

    subject.send(1)
    XCTAssertEqual(values, [1])

    subject.send(completion: .finished)
    XCTAssertEqual(values, [1])

    _ = Effect<Never, Never>.cancel(id: CancelToken())
      .sink { _ in }
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1])
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

    let effect = Effect.merge(
      (1...1_000).map { idx -> Effect<Int, Never> in
        let id = idx % 10

        return Effect.merge(
          Just(idx)
            .delay(
              for: .microseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
            )
            .eraseToEffect()
            .cancellable(id: id),

          Just(())
            .delay(
              for: .microseconds(Int.random(in: 1...100)), scheduler: queues.randomElement()!
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

    XCTAssertTrue(cancellationCancellables.isEmpty)
  }
}

func resetCancellables() {
  for (id, _) in cancellationCancellables {
    cancellationCancellables[id] = [:]
  }
  cancellationCancellables = [:]
}
