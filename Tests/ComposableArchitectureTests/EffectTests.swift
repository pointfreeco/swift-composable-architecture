import Combine
import XCTest

@testable import ComposableArchitecture

final class EffectTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []
  let scheduler = DispatchQueue.testScheduler

  func testEraseToEffectWithError() {
    struct Error: Swift.Error, Equatable {}

    Future<Int, Error> { $0(.success(42)) }
      .catchToEffect()
      .sink { XCTAssertEqual($0, .success(42)) }
      .store(in: &self.cancellables)

    Future<Int, Error> { $0(.failure(Error())) }
      .catchToEffect()
      .sink { XCTAssertEqual($0, .failure(Error())) }
      .store(in: &self.cancellables)

    Future<Int, Never> { $0(.success(42)) }
      .eraseToEffect()
      .sink { XCTAssertEqual($0, 42) }
      .store(in: &self.cancellables)
  }

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: scheduler).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: scheduler).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 2)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 3)
    XCTAssertEqual(values, [1, 2, 3])

    self.scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int, Never>.concatenate(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect()
    )

    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.run()
    XCTAssertEqual(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int, Never>.merge(
      Effect(value: 1).delay(for: 1, scheduler: scheduler).eraseToEffect(),
      Effect(value: 2).delay(for: 2, scheduler: scheduler).eraseToEffect(),
      Effect(value: 3).delay(for: 3, scheduler: scheduler).eraseToEffect()
    )

    var values: [Int] = []
    effect.sink(receiveValue: { values.append($0) }).store(in: &self.cancellables)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testEffectSubscriberInitializer() {
    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      subscriber.send(2)
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(1))) {
        subscriber.send(3)
      }
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(2))) {
        subscriber.send(4)
        subscriber.send(completion: .finished)
      }

      return AnyCancellable {}
    }

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1, 2])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3, 4])
    XCTAssertEqual(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    struct CancelId: Hashable {}

    let effect = Effect<Int, Never>.run { subscriber in
      subscriber.send(1)
      self.scheduler.schedule(after: self.scheduler.now.advanced(by: .seconds(1))) {
        subscriber.send(2)
      }

      return AnyCancellable {}
    }
    .cancellable(id: CancelId())

    var values: [Int] = []
    var isComplete = false
    effect
      .sink(receiveCompletion: { _ in isComplete = true }, receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    Effect<Void, Never>.cancel(id: CancelId())
      .sink(receiveValue: { _ in })
      .store(in: &self.cancellables)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }
}
